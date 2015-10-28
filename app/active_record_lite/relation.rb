class Relation

  def initialize(params, original_class)
    @params = params
    @class = original_class
  end

  def where_line
    @params.map {|key, val| "#{key} = ?" }.join(" AND ")
  end

  def where(params)
    @params.merge(params)
    self
  end

  def each(&prc)
    execute.each do |entry|
      prc.call(entry)
    end
  end

  def param_vals
    @params.values
  end

  def execute
    results = DBConnection.execute(<<-SQL, *param_vals)
    SELECT
      *
    FROM
      #{@class.table_name}
    WHERE
      #{where_line}
    SQL
    @class.parse_all(results)
  end

  def method_missing(method_name, *args)
    value = execute
    value.send(method_name.to_sym, *args)
  end

end
