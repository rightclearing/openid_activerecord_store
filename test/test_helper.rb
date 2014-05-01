require 'minitest'
require 'minitest/autorun'
require 'minitest/pride'
require 'rails'
require 'openid_active_record_store'
require 'active_record'

db = {
  :adapter  => :mysql2,
  :database => 'openid_active_record_store',
  :username => 'developer'
}

# XXX  yes, there are better ways. patches please!

ActiveRecord::Base.establish_connection db

ActiveRecord::Base.connection.drop_database db[:database]
ActiveRecord::Base.connection.create_database db[:database]

ActiveRecord::Base.establish_connection db

Dir['db/migrate/*.rb'].each do |migration|
  require migration
  Object.const_get(File.basename(migration, '.rb').camelize).up
end

Dir['app/models/*.rb'].each do |model|
  require File.expand_path(model)
end