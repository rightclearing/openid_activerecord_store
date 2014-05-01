# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name     = %q{openid_active_record_store}
  s.version  = "2.0.0"
  s.authors  = ['James Tucker', 'Kazuyoshi Tlacaelel', 'Beat Richartz']
  s.email    = 'attr_accessor@gmail.com'
  s.homepage = 'http://github.com/rightclearing/openid_active_record_store'

  s.date          = %q{2011-05-24}
  s.licenses      = [%q{MIT}]
  s.require_paths = [%q{lib}]
  s.summary       = 'An ActiveRecord 4 store for OpenID'
  s.description   = 'An ActiveRecord 4 store for OpenID'

  s.files = `git ls-files`.split - %W[.gitignore #{File.basename __FILE__}]

  s.add_dependency("activerecord", ["~> 4.1"])
  s.add_dependency("ruby-openid", ["~> 2.5"])
  s.add_development_dependency("rails", ["~> 4.1"])
  s.add_development_dependency("mysql2", ["~> 0.3"])
end
