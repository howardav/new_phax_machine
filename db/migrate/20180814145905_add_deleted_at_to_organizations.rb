class AddDeletedAtToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :deleted_at, :datetime
    add_index :organizations, :deleted_at
  end
end
