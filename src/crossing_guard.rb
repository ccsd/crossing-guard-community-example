# AWS/SQS queue poller for enrollment_created|updated events
# reconciles changes against rules
# frozen_string_literal: false

class CrossingGuard
  attr_accessor :user_interrupt

  def initialize
    # CFG, DB, DB_PARAMS, DOMAIN_SHARD_ID
    @env = 'beta'
    @queue = @env == 'production' ? CFG['aws']['queue']: CFG['aws']['qbeta']
    env = @env + '.' unless @env == 'production'
    @inst_env_domain = ".#{env}instructure.com"

    @logger = Logger.new("#{CFG[:path]}/logs/xguard-#{@env}.log", 'daily')
    @requests_log = Logger.new("#{CFG[:path]}/logs/xguard-#{@env}-requests.log", 'daily')
  end

  def run!
    # handle graceful exit from user or daemon
    self.user_interrupt = false
    Signal.trap('INT') { exit_after_completion('INT') }
    Signal.trap('TERM') { exit_after_completion('TERM') }
    File.open("#{CFG[:path]}/logs/xguard-daemon.pid", 'w') { |f| f << Process.pid }
    # start polling
    poll!
  end

  def poll!
    credentials = Aws::Credentials.new(CFG['aws']['access_key_id'], CFG['aws']['secret_access_key'])
    Aws.config.update({ credentials: credentials, region: CFG['aws']['region'] })
    poller = Aws::SQS::QueuePoller.new(@queue)
    poller.before_request { stop! if user_interrupt == true }
    poller.poll do |msg|
      begin
        event = JSON.parse(msg.body)
        next if event['body']['type'] == 'StudentViewEnrollment'

        # enrollments from other instances, because of consortium pop-ins... deal with below
        # next unless DOMAIN_SHARD_ID.select { |i,id| i if event['body']['enrollment_id'].start_with? id }.any?

        # associated student/observer pair
        next if event['body']['type'] == 'ObserverEnrollment' && event['metadata']['user_sis_id'].nil? && !event['body']['associated_user_id'].nil?

        # expect a second enrollment_updated event for any enrollment updated
        guard = reconcile(event)
        @logger.info(guard.to_json) unless guard[:status].nil?
        if $stdout.isatty
          puts "ignored" if guard[:status].nil?
          puts "CROSSING GUARD: #{guard[:rule]}" unless guard[:status].nil?
        end
      rescue StandardError => e
        # error in the routine, skip delete to try the message again later
        @logger.debug("#{e}\n#{msg.message_id} : #{event}")
        puts "#{e}\n#{msg.body}" if $stdout.isatty
        throw :skip_delete
      end
    end
  end

  # stops the poller and process, no need to exit
  def stop!
    puts 'polling stopped' if $stdout.isatty
    @logger.info('polling stopped')
    throw :stop_polling
  end

  # sets the :user_interrupt flag to stop polling after current message
  def exit_after_completion(signal)
    puts "\r#{signal}: exit after completion" if $stdout.isatty
    self.user_interrupt = true
  end

  def reconcile(change)
    begin
      hallpass = { status: nil, rule: nil }
      enrollment = canvas_enrollment(change)
      return hallpass if enrollment.nil?

      # hall pass - ignore specified groups
      return hallpass if enrollment['sis_user_id'].to_s.match?(/EDDEPT-|UNIV-|COLL-/)

      # hall monitor - constrain groups by sis_user_id PREFIX
      case enrollment['sis_user_id']
      when /^DEPT-|^ANOTH-|^VENDOR-/i
        
        return hallpass if change['body']['workflow_state'] == 'deleted'

        # keep non-sis users out of sis courses
        if !enrollment['sis_section_id'].nil?
          hallpass[:rule] = 'hall monitor! non-sis user group not allowed in sis courses'
          hallpass[:status] = delete(change) unless %w[deleted inactive].any? change['body']['workflow_state']
        end

        return hallpass

      when /^PLS-/i
        if !enrollment['sis_account_id'].nil? && !enrollment['sis_course_id'].nil?
          
          # ignore if user is in profressional development managed sis account/courses
          return hallpass if ((enrollment['sis_account_id'] =~ /^PLS/i) == 0) && ((enrollment['sis_course_id'] =~ /^PLS/i) == 0)
    
          hallpass[:rule] = 'hall monitor! PL users only in PL courses/accounts'
          hallpass[:status] = delete(change) unless %w[deleted inactive].any? change['body']['workflow_state']
          
          return hallpass
        end

      when /^DEMO-student/i
        # verify sub accounts for documentation demos
        return hallpass if (enrollment['sis_account_id'] =~ /^NSO|^MATH|^ENG/i) == 0

        hallpass[:rule] = 'hall monitor! demo users only demo sub accounts'
        hallpass[:status] = delete(change) unless %w[deleted inactive].any? change['body']['workflow_state']

        return hallpass
      end

      guard = {
        status: nil,
        rule: nil,
        changed_user_name: change['body']['user_name'],
        sis_user: sis_user(enrollment['sis_user_id']),
        sis_course_id: change['metadata']['context_sis_source_id'],
        sis_section_id: enrollment['sis_section_id'],
        enrollment: enrollment,
        event: change['metadata']['event_name'],
        enrollment_id: change['body']['enrollment_id'],
        canvas_course_id: change['metadata']['context_id'],
        course_section_id: change['body']['course_section_id'],
        enrollment_type: change['body']['type'],
        workflow_state: change['body']['workflow_state']
      }

      case change['body']['type']
      when /DesignerEnrollment|TaEnrollment|TeacherEnrollment/
        # only employees in these roles
        # delete any enrollment for user not found in employee table
        if guard[:sis_user].keys.first == :not_an_sis_user || guard[:sis_user].keys.first == :student
          guard[:rule] = "#{change['body']['type']}: must be an employee"
          guard[:status] = delete(change) unless %w[deleted inactive].any? change['body']['workflow_state'] # ['deleted','inactive']

        elsif guard[:sis_user].keys.first == :employee
          # allow any employee role/state
          case change['body']['workflow_state']
          when /deleted|inactive/
            # validate employee enrollment, if assigned teacher of record re-activate
            course_sis_id = guard[:sis_section_id] || guard[:sis_course_id]
            active_enrollment = sis_enrollment(guard[:sis_user], course_sis_id)
            if !active_enrollment.nil?
              active_enrollment[:section_id] = course_sis_id
              guard[:status] = restore(change, active_enrollment) unless active_enrollment.nil?
              guard[:rule] = "#{change['body']['type']}: cannot delete an active teacher of record" unless active_enrollment.nil?
            end
          end
        end

      when 'StudentEnrollment'
        # not an sis user
        if guard[:sis_user].keys.first == :not_an_sis_user
          guard[:rule] = "#{change['body']['type']}: students must be an sis user"
          guard[:status] = delete(change) unless %w[deleted inactive].any? change['body']['workflow_state']
        else
          # any sis user can be a student
          # students can be added to a course
          # if deleted, must reconcile student enrollment for course, if no enrollments, ignore
          case change['body']['workflow_state']
          when /deleted|inactive/
            # enrollment should match sis, or not exist
            course_sis_id = guard[:sis_section_id] || guard[:sis_course_id]
            active_enrollment = sis_enrollment(guard[:sis_user], course_sis_id)
            if !active_enrollment.nil?
              active_enrollment[:section_id] = course_sis_id
              guard[:status] = restore(change, active_enrollment)
              guard[:rule] = "#{change['body']['type']}: cannot delete an active student sis enrollment"
            end
          end
        end

      when 'ObserverEnrollment'
        # anyone can be an observer and can be removed from the role
        # students can be observers, but not of a course they are enrolled in via SIS, correct the enrollment
        if guard[:sis_user].keys.first == :student
          active_enrollment = sis_enrollment(guard[:sis_user], guard[:sis_section_id])
          if !active_enrollment.nil?
            guard[:status] = delete(change)
            guard[:rule] = "#{change['body']['type']}: student with sis enrollment in section cannot be observer of course"
          end
        end
      end
      guard
    rescue => e
      puts e.message
      puts e.backtrace
    end
  end

  def canvas_enrollment(enrollment_msg)
    # here we can't always use the hostname from the event to hit the correct instance
    # some enrollments ids don't reference the right hostname in the message
    # ex: observer pairing and accepted invitiations
    # with trust/consortium, ideally, would like to lookup a global_id against any instance
    # for now, remap
    enrollment_hostname = DOMAIN_SHARD_ID.select { |i,id| i if enrollment_msg['body']['enrollment_id'].start_with? id }.keys.first + @inst_env_domain

    canvas = Faraday.new(url: "https://#{enrollment_hostname}/api/v1/") do |f|
      f.use Faraday::Response::Logger, @requests_log do |requests|
        requests.filter(/(Bearer )(.*)/, '\1[REMOVED]')
      end
      # f.authorization :Bearer, CFG['api']['token']
      f.request :authorization, 'Bearer', CFG['api']['token']
      f.headers['User-Agent'] = CFG['api']['user_agent']
      f.request :multipart
      f.request :url_encoded
      f.adapter :net_http
    end
    canvas.options.timeout = 60
    canvas.options.open_timeout = 60
    res = canvas.get("accounts/self/enrollments/#{enrollment_msg['body']['enrollment_id']}", nil, { 'Accept' => 'application/json' })
    # byebug if res.status == 404
    @logger.debug("enrollment not found:\n#{enrollment_msg.to_json}") if res.status == 404
    # TODO: has to...retry or try course user enrollment lookup?
    return nil if res.status == 404

    JSON.parse(res.body) if res.status == 200
  end

  def delete(enrollment_msg)
    context_course_id = enrollment_msg['metadata']['context_id'] || enrollment_msg['body']['course_id']
    # byebug if enrollment_msg['metadata']['context_id'].nil?

    # must use the hostname from the event for the correct instance
    canvas = Faraday.new(url: "https://#{enrollment_msg['metadata']['hostname']}/api/v1/") do |f|
      f.use Faraday::Response::Logger, @requests_log do |requests|
        requests.filter(/(Bearer )(.*)/, '\1[REMOVED]')
      end
      # f.authorization :Bearer, CFG['api']['token']
      f.request :authorization, 'Bearer', CFG['api']['token']
      f.headers['User-Agent'] = CFG['api']['user_agent']
      f.request :multipart
      f.request :url_encoded
      f.adapter :net_http
    end
    canvas.options.timeout = 60
    canvas.options.open_timeout = 60
    res = canvas.delete("courses/#{context_course_id}/enrollments/#{enrollment_msg['body']['enrollment_id']}?task=delete", nil, 'Accept' => 'application/json')
    status = JSON.parse(res.body)
    @logger.debug("not deleted:\n#{enrollment_msg.to_json}") if res.status != 200 || status['enrollment_state'] != 'deleted'
    'deleted!' if status['enrollment_state'] == 'deleted'
  end

  def restore(enrollment_msg, sis_enrollment)
    # must use the hostname from the event to hit the correct instance
    canvas = Faraday.new(url: "https://#{enrollment_msg['metadata']['hostname']}/api/v1/") do |f|
      f.use Faraday::Response::Logger, @requests_log do |requests|
        requests.filter(/(Bearer )(.*)/, '\1[REMOVED]')
      end
      # f.authorization :Bearer, CFG['api']['token']
      f.request :authorization, 'Bearer', CFG['api']['token']
      f.headers['User-Agent'] = CFG['api']['user_agent']
      f.request :multipart
      f.request :url_encoded
      f.adapter :net_http
    end
    canvas.options.timeout = 60
    canvas.options.open_timeout = 60
    params = {
      enrollment: {
        start_at: Time.parse(sis_enrollment[:updated].to_s).strftime('%Y-%m-%dT%H:%M:%SZ'),
        user_id: enrollment_msg['body']['user_id'],
        type: sis_enrollment[:role].capitalize + 'Enrollment',
        enrollment_state: sis_enrollment[:status]
      }
    }
    res = canvas.post("sections/sis_section_id:#{sis_enrollment[:section_id]}/enrollments", params)
    status = JSON.parse(res.body)
    # TODO: if 404, check if the user has enrollment
    @logger.debug("not restored:\n#{enrollment_msg.to_json}\n#{sis_enrollment.to_json}\n#{status}") if res.status != 200 || status['enrollment_state'] != 'active'
    'active!' if status['enrollment_state'] == 'active'
  end

  def sis_user(sis_user_id)
    # TODO: some eager staff enroll students before they exist in our tables
    # sometimes the user exists in Canvas, but we haven't caught up with that user enrolled this year
    # run secondary lookup against SIS source
    @logger.debug("{ not_an_sis_user: true } : #{sis_user_id}") if sis_user_id.nil?
    return { not_an_sis_user: true } if sis_user_id.nil?

    sis_employee = DB['EXEC xg_employees @user_id = ?', :$u].call(:select, u: sis_user_id).first if sis_user_id.start_with? 'E'
    return { employee: sis_employee } unless sis_employee.nil?

    sis_student = DB['EXEC xg_students @user_id = ?', :$u].call(:select, u: sis_user_id).first if sis_user_id.scan(/\D/).empty?
    return { student: sis_student } unless sis_student.nil?
    # byebug
    
    { not_an_sis_user: true }
  rescue => e
    retry if db_reconnect(e.message)
  end

  def sis_enrollment(sis_user, sis_section_id)
    return nil if sis_section_id.nil?

    if sis_user.keys.first == :employee
      DB['EXEC xg_teacher_enrollments @user_id = ?, @section_id = ?, @status = ?', :$user_id, :$section_id, :$status].call(:select, user_id: sis_user[:employee][:user_id], section_id: sis_section_id, status: 'active').first
    elsif sis_user.keys.first == :student
      DB['EXEC xg_student_enrollments @user_id = ?, @section_id = ?, @status = ?', :$user_id, :$section_id, :$status].call(:select, user_id: sis_user[:student][:user_id], section_id: sis_section_id, status: 'active').first
    end
  rescue => e
    retry if db_reconnect(e.message)
  end

  def db_reconnect(err_str)
    return false if connection_error?(err_str) == false

    DB.connect(DB_PARAMS) if DB.disconnect
    raise err_str if DB.test_connection != true

    DB.test_connection
  rescue => e
    @logger.fatal(e.message)
    raise e.message
  end
end
