# frozen_string_literal: true

class CreateServices < ActiveRecord::Migration[4.2]
  def self.up
    create_table :services, id: :bigint do |t|
      t.string :name, :null => false, :limit => 255, :required => true
      t.string :ref, :null => false, :limit => 255, :required => true, :default => "master"
    end
    add_index :services, [:name], :unique => true, :name => 'on_name'

    add_column :pushes, :service_id, :integer, :limit => 8, :null => false

    add_index :pushes, [:service_id], :name => 'on_service_id'

    web_service = Service.create!(name: 'web', ref: 'production')
    Service.create!(
      [
        { name: 'rs_west',    ref: 'd72f6b040022211872a52cdc48c72fd0560bd402' },
        { name: 'rs_east',    ref: 'd72f6b040022211872a52cdc48c72fd0560bd402' },
        { name: 'rs_central', ref: 'd72f6b040022211872a52cdc48c72fd0560bd402' }
      ]
    )
    Push.update_all(service_id: web_service.id)
  end

  def self.down
    remove_column :pushes, :service_id

    drop_table :services

    remove_index :pushes, :name => :on_service_id rescue ActiveRecord::StatementInvalid
  end
end
