# frozen_string_literal: true

class WidenTextColumns < ActiveRecord::Migration[5.0]
  def change
    migrate! do
      change_table! 'delayed_jobs' do
        change_column! 'handler', :text, null: false do
          up!   limit: 0xffff_ffff
          down! limit: 0xffff
        end
        change_column! 'last_error', :text, null: true do
          up!   limit: 0xffff_ffff
          down! limit: 0xffff
        end
      end

      change_table! 'branches' do
        change_column! 'name', null: false do
          up!   :string, limit: 1024
          down! :text,   limit: 0xffff
        end
      end

      change_table! 'commits' do
        change_column! 'sha', limit: 255, null: false do
          up!   :string
          down! :text
        end
        change_column! 'message', :text, null: false do
          up!   limit: 0xffff_ffff
          down! limit: 0xffff
        end
      end

      change_table! 'commits_and_pushes' do
        change_column! 'errors_json', null: true do
          up!   :text,   limit: 0xffff_ffff
          down! :string, limit: 256
        end
      end

      change_table! 'jira_issues' do
        change_column! 'key', null: false do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
        change_column! 'issue_type', null: false do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
        change_column! 'summary', :text, null: false do
          up!   limit: 0xffff_ffff
          down! limit: 0xffff
        end
        change_column! 'status', null: false do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
        change_column! 'post_deploy_check_status', null: true do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
        change_column! 'deploy_type', null: true do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
        change_column! 'long_running_migration', null: true do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
      end

      change_table! 'jira_issues_and_pushes' do
        change_column! 'errors_json', null: true do
          up!   :text,   limit: 0xffff_ffff
          down! :string, limit: 256
        end
      end

      change_table! 'repositories' do
        change_column! 'name', null: false do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
      end

      change_table! 'users' do
        change_column! 'name', null: false do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
        change_column! 'email', null: false do
          up!   :string, limit: 255
          down! :text,   limit: 0xffff
        end
      end
    end
  end

  private

  def migrate!(&block)
    dsl = MigrationDsl.new
    dsl.instance_exec(&block)

    reversible do |dir|
      dsl.execute!(dir, self)
    end
  end

  class MigrationDsl
    def initialize
      @tables = []
    end

    def change_table!(table, &block)
      dsl = TableDsl.new(table)
      dsl.instance_exec(&block)
      @tables << dsl
    end

    def execute!(dir, binding)
      @tables.each do |dsl|
        dsl.execute!(dir, binding)
      end
    end
  end

  class TableDsl
    def initialize(table)
      @table = table
      @columns = []
    end

    def change_column!(column_name, type = nil, **common_hash, &block)
      dsl = ColumnDsl.new(column_name)
      dsl.instance_exec(&block)
      @columns << [dsl, type, common_hash]
    end

    def execute!(dir, binding)
      binding.change_table @table do |table|
        @columns.each do |column, type, common_hash|
          column.execute!(dir, table, type, common_hash)
        end
      end
    end
  end

  class ColumnDsl
    def initialize(column_name)
      @column_name = column_name
      @up   = []
      @down = []
    end

    def up!(type = nil, **hash)
      @up << [:change, @column_name, type, hash]
    end

    def down!(type = nil, **hash)
      @down << [:change, @column_name, type, hash]
    end

    def execute!(dir, table, common_type, common_hash)
      execute_dir!(dir, table, common_type, common_hash, :up,   @up)
      execute_dir!(dir, table, common_type, common_hash, :down, @down)
    end

    private

    def execute_dir!(dir, table, common_type, common_hash, direction, commands)
      dir.send(direction) do
        commands.each do |init_args|
          args = init_args.dup
          if common_type
            if common_type != args[1]
              args[2] and raise ArgumentError, "common type #{common_type.inspect} clashes with explicit type #{args[2].inspect}"
              args = args.dup
              args[2] = common_type
            end
          else
            args[2] or raise ArgumentError, "type must be given: #{args.inspect}"
          end

          args.last.merge!(common_hash)
          table.send(*args)
        end
      end
    end
  end
end
