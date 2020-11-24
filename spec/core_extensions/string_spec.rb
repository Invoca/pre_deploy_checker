# frozen_string_literal: true

require 'spec_helper'

describe 'CoreExtensions::String' do
  before(:all) do
    String.include CoreExtensions::String
  end

  describe 'escape_double_quotes' do
    it 'escapes double quotes' do
      expect('word"word'.escape_double_quotes).to eq('word\\"word')
    end

    it 'does not escape single quotes' do
      expect('word\'word'.escape_double_quotes).to eq('word\'word')
    end

    it 'handles strings without any quotes' do
      expect('word'.escape_double_quotes).to eq('word')
    end

    it 'handles empty strings' do
      expect(''.escape_double_quotes).to eq('')
    end
  end

  describe 'escape_double_quotes!' do
    it 'escapes double quotes' do
      string = 'word"word'
      string.escape_double_quotes!
      expect(string).to eq('word\\"word')
    end

    it 'does not escape single quotes' do
      string = 'word\'word'
      string.escape_double_quotes!
      expect(string).to eq('word\'word')
    end

    it 'handles strings without any quotes' do
      string = 'word'
      string.escape_double_quotes!
      expect(string).to eq('word')
    end

    it 'handles empty strings' do
      string = ''
      string.escape_double_quotes!
      expect(string).to eq('')
    end
  end
end
