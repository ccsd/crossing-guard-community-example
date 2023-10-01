# frozen_string_literal: false

DB_PARAMS = {
  adapter: CFG['db']['adapter'],
  host: CFG['db']['host'],
  database: CFG['db']['data'],
  user: CFG['db']['user'],
  password: CFG['db']['pass'],
  max_connections: CFG['db']['max_connections'],
  ansi: true, # sql server
  encoding: 'utf8',
  timeout: CFG['db']['timeout'],
  pool_timeout: CFG['db']['pool_timeout'],
  logger: Logger.new("#{CFG[:path]}/logs/db-crossing_guard.log", 'daily')
}.freeze

def db_conn
  # db connection parameters
  db = Sequel.connect(DB_PARAMS)
  # https://sequel.jeremyevans.net/plugins.html
  db.extension :connection_validator
  db.extension :error_sql
  db.extension :identifier_mangling
  db.identifier_input_method = :downcase
  db
rescue => e
  raise e
end

# check the connection
def try_db_connection
  DB.test_connection
rescue => e
  raise e
end

# connect
DB = db_conn
raise 'no db' unless try_db_connection

CONNECTION_ERRORS = [
  # tinytds
  'Adaptive Server connection timed out',
  'Cannot continue the execution because the session is in the kill state',
  'Login failed for user',
  'Read from the server failed',
  'Server name not found in configuration files',
  'The transaction log for database',
  'Unable to access availability database',
  'Unable to connect: Adaptive Server is unavailable or does not exist',
  'Write to the server failed',
  'Cannot open user default database. Login failed.',
  'is being recovered. Waiting until recovery is finished',
  'because the database replica is not in the PRIMARY or SECONDARY role',
  'is participating in an availability group and is currently not accessible for queries',
  'DBPROCESS is dead or not enabled'
].freeze

def connection_error?(err_str)
  err_str.match? Regexp.union(CONNECTION_ERRORS)
end
