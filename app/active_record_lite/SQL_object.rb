require 'active_support/inflector'
require_relative 'db_connection'
require_relative 'relation'


class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    @class_name.camelcase.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    params = {
      foreign_key: (name.to_s + "_id").to_sym,
      class_name: name.to_s.camelcase,
      primary_key: :id
    }
    params = params.merge(options)
    @class_name, @foreign_key, @primary_key =
    params[:class_name], params[:foreign_key], params[:primary_key]
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    params = {
      foreign_key: (self_class_name.underscore + "_id").to_sym,
      class_name: name.to_s.singularize.camelcase,
      primary_key: :id
    }
    params = params.merge(options)
    @class_name, @foreign_key, @primary_key =
    params[:class_name], params[:foreign_key], params[:primary_key]
  end
end

module Associatable

  def belongs_to(name, options = {})
    options = BelongsToOptions.new(name, options)
    assoc_options[name] = options
    define_method(name) do
        foreign_key_id = self.send(:id)
        other_class = options.model_class
        other_class.where(options.primary_key => foreign_key_id).first
      end
  end

  def has_many(name, options = {})
    options = HasManyOptions.new(name, self.name, options)
    define_method(name) do
        primary_key_id = self.send(:id)
        other_class = options.model_class
        other_class.where(options.foreign_key => primary_key_id)
    end
  end

  def has_one_through(name, through_name, source_name)
    define_method(name) do
        through_options = self.class.assoc_options[through_name]

        source_options =
        through_options.model_class.assoc_options[source_name]

        results =
        DBConnection.execute(<<-SQL, self.send(through_options.foreign_key))
        SELECT
          #{source_options.table_name}.*
        FROM
          #{through_options.table_name}
        JOIN
          #{source_options.table_name}
        ON
          #{through_options.table_name}.#{source_options.foreign_key} =
          #{source_options.table_name}.#{ source_options.primary_key }
        WHERE
          #{through_options.table_name}.#{ through_options.primary_key } =
          ?
        SQL
        source_options.model_class.parse_all(results).first
      end
    end

    # def has_many_through(name, through_name, source_name)
    #   define_method(name) do
    #       through_options = self.class.assoc_options[through_name]
    #
    #       source_options =
    #       through_options.model_class.assoc_options[source_name]
    #       key_value = send(through_options.send("primary_key"))
    #       key_name = through_options.send("foreign_key")
    #       results =
    #       DBConnection.execute(<<-SQL, key_value)
    #       SELECT
    #         #{source_options.table_name}.*
    #       FROM
    #         #{through_options.table_name}
    #       JOIN
    #         #{source_options.table_name}
    #       ON
    #         #{through_options.table_name}.#{source_options.foreign_key} =
    #         #{source_options.table_name}.#{ source_options.primary_key }
    #       WHERE
    #         #{through_options.table_name}.#{key_name } =
    #         ?
    #       SQL
    #       source_options.model_class.parse_all(results)
    #   end
    # end

  def assoc_options
    @assoc_options ||= {}
  end

end


class SQLObject
  extend Associatable

  def self.columns
    output = DBConnection.execute2(<<-SQL)
    SELECT
      *
    FROM
      #{self.table_name}
    SQL
    columns = output.first.map(&:to_sym)
  end

  def self.finalize!

    self.columns.each do |var_name|
      define_method(var_name) do
        self.attributes[var_name]
      end

      setter_name = (var_name.to_s + '=').to_sym
      define_method(setter_name) do |value|
        self.attributes[var_name] = value
      end

    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
      SQL
    self.parse_all(results)
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = ?
      SQL

    self.parse_all(results).first
  end

  def self.parse_all(results)
    results.each_with_object([]) do |object_params, results|
    results << self.new(object_params)
    end
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      unless self.class.columns.include?(attr_name.to_sym)
        raise "unknown attribute '#{attr_name}'"
      end
      setter = attr_name.to_s + "="
      self.send(setter.to_sym, value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    attributes.values
  end

  def insert
    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{questions_marks})
      SQL
    self.send(:id=, DBConnection.instance.last_insert_row_id)
  end

  def where(params)
    Relation.new(params, self)
  end

  def questions_marks
    @attributes.values.map { "?" }.join(", ")
  end

  def col_names
    @attributes.keys.map {|key| key.to_s }.join(", ")
  end

  def col_setters
    self.class.columns.map do |col_name|
      "#{col_name} = ?"
    end.join(", ")
  end

  def update
    DBConnection.execute(<<-SQL, *attribute_values)
    UPDATE
      #{self.class.table_name}
    SET
      #{col_setters}
    WHERE
      id = #{self.id}
    SQL
  end

  def save
    if self.id.nil?
      insert
    else
      update
    end
  end


end
