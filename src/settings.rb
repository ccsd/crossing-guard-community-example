# frozen_string_literal: false

# path
env = { path: Dir.pwd }

# api config
CFG = env.merge(YAML.load_file("#{env[:path]}/config/guard.yml"))
CFG['api']['token'] = ENV['XPACK_LMS_KEY'] || CFG['api']['token']
DOMAIN_SHARD_ID     = CFG['domain_shard_id'].freeze

# sqs token
CFG_SQS = env.merge(YAML.load_file("#{env[:path]}/config/sqs.yml"))
CFG['aws'] = CFG_SQS
CFG['aws']['access_key_id'] = ENV['XGUARD_SQS_KEY'] || CFG_SQS['aws']['access_key_id']
CFG['aws']['secret_access_key'] = ENV['XGUARD_SQS_SECRET'] || CFG_SQS['aws']['secret_access_key']
CFG['aws']['region'] = CFG_SQS['aws']['region']
CFG['aws']['queue'] = ENV['XGUARD_QUEUE'] || CFG_SQS['aws']['queue']
CFG['aws']['qbeta'] = ENV['XGUARD_QBETA'] || CFG_SQS['aws']['qbeta']

# database config
CFG_DB = YAML.load_file("#{env[:path]}/config/database.yml")
CFG['db'] = CFG_DB
# db credentials: favor ENV over YAML
CFG['db']['host'] = ENV['SIS_DB_HOST'] || CFG_DB['host']
CFG['db']['data'] = ENV['SIS_DB_NAME'] || CFG_DB['data']
CFG['db']['user'] = ENV['SIS_XG_USER'] || CFG_DB['user']
CFG['db']['pass'] = ENV['SIS_XG_PASS'] || CFG_DB['pass']
