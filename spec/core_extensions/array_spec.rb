# frozen_string_literal: true

require 'spec_helper'

describe 'CoreExtensions::Array' do
  before(:all) do
    Array.include CoreExtensions::Array
  end

  describe 'include_regexp?' do
    it 'can include? regular expressions for array of regular expression strings' do
      array = ['.*world', '.*moon']

      expect(array.include_regexp?('hello_world')).to be_truthy
      expect(array.include_regexp?('hello_moon')).to be_truthy
      expect(array.include_regexp?('hello_space')).to be_falsey
    end

    it 'can include? regular expressions for array of regular expressions' do
      array = [/.*world/, /.*moon/]

      expect(array.include_regexp?('hello_world')).to be_truthy
      expect(array.include_regexp?('hello_moon')).to be_truthy
      expect(array.include_regexp?('hello_space')).to be_falsey
    end

    it 'can accept regexp options for array of regular expression strings' do
      array = ['.*world', '.*moon']

      expect(array.include_regexp?('hello_WORLD', regexp_options: Regexp::IGNORECASE)).to be_truthy
    end
  end

  describe 'reject_regexp' do
    it 'can reject strings that match a regular expression' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regexp(/.*world/)).to match_array(['hello_moon'])
      expect(array.reject_regexp(/hello.*/)).to match_array([])
      expect(array.reject_regexp(/nomatch.*/)).to match_array(['hello_world', 'hello_moon'])
    end

    it 'can reject strings that match an array of regular expressions' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regexp([/.*world/])).to match_array(['hello_moon'])
      expect(array.reject_regexp([/.*world/, /.*moon/])).to match_array([])
      expect(array.reject_regexp([/hello.*/])).to match_array([])
      expect(array.reject_regexp([/nomatch.*/])).to match_array(['hello_world', 'hello_moon'])
    end

    it 'can reject strings that match an array of regular expression strings' do
      array = ['hello_world', 'hello_moon']

      expect(array.reject_regexp(['.*world'])).to match_array(['hello_moon'])
      expect(array.reject_regexp(['.*world', '.*moon'])).to match_array([])
      expect(array.reject_regexp(['hello.*'])).to match_array([])
      expect(array.reject_regexp(['nomatch.*'])).to match_array(['hello_world', 'hello_moon'])
    end

    it 'can reject regexp options for array of regular expression strings' do
      array = ['hello_WORLD', 'hello_moon']

      expect(array.reject_regexp(['.*world'], regexp_options: Regexp::IGNORECASE)).to match_array(['hello_moon'])
    end
  end

  describe 'select_regexp' do
    it 'can select strings that match a regular expression' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regexp(/.*world/)).to match_array(['hello_world'])
      expect(array.select_regexp(/hello.*/)).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regexp(/nomatch.*/)).to match_array([])
    end

    it 'can select strings that match an array of regular expressions' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regexp([/.*world/])).to match_array(['hello_world'])
      expect(array.select_regexp([/.*world/, /.*moon/])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regexp([/hello.*/])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regexp([/nomatch.*/])).to match_array([])
    end

    it 'can select strings that match an array of regular expression strings' do
      array = ['hello_world', 'hello_moon']

      expect(array.select_regexp(['.*world'])).to match_array(['hello_world'])
      expect(array.select_regexp(['.*world', '.*moon'])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regexp(['hello.*'])).to match_array(['hello_world', 'hello_moon'])
      expect(array.select_regexp(['nomatch.*'])).to match_array([])
    end

    it 'can accept regexp options for array of regular expression strings' do
      array = ['hello_WORLD', 'hello_moon']

      expect(array.select_regexp(['.*world'], regexp_options: Regexp::IGNORECASE)).to match_array(['hello_WORLD'])
    end
  end
end
