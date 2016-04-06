require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @table ||= DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        '#{self.table_name}'
    SQL
    column_names = @table.first.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |column|
      define_method("#{column}") do
        # instance_variable_get("@#{column}")
        @attributes ||= {}
        @attributes[column]
      end

      define_method("#{column}=") do |value|
        # instance_variable_set("@#{column}",value)
        @attributes ||= {}
        @attributes[column] = value
      end

    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.to_s.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
    SELECT
      *
    FROM
      '#{self.table_name}'
    SQL
    self.parse_all(results)
  end

  def self.parse_all(results)
    results.map do |result_hash|
      self.new(result_hash)
    end

  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
    SELECT
      *
    FROM
      #{self.table_name}
    WHERE
      #{self.table_name}.id = ?
    SQL
    self.parse_all(results).first
  end

  def initialize(params = {})
    params.each do |attr_name,v|
      raise "unknown attribute '#{attr_name}'" unless self.class.columns.include?(attr_name.to_sym)
      self.send("#{attr_name}=", v)
    end

  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    @attributes.values
  end

  def insert
    all_columns = self.class.columns.drop(1)
    col_names = all_columns.join(',')
    question_marks = (['?'] * (all_columns.length)).join(',')

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    columns_arr = self.class.columns.drop(1)
    set = (0...columns_arr.length).map {|i| "#{columns_arr[i]} = ?"}
    set = set.join(', ')

    DBConnection.execute(<<-SQL, *attribute_values.rotate(1))
      UPDATE
        #{self.class.table_name}
      SET
        #{set}
      WHERE
        id = ?
    SQL
  end

  def save
    self.id.nil? ? insert : update
  end
end
