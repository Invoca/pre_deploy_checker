# frozen_string_literal: true

begin
  require 'coveralls/rake/task'
  Coveralls::RakeTask.new
rescue LoadError => ex
  puts "LoadError from coveralls:\n#{ex.backtrace}"
end
