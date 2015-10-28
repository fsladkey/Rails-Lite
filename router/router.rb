require_relative './controller_base'

class Route
  attr_reader :pattern, :http_method, :controller_class, :action_name

  def initialize(pattern, http_method, controller_class, action_name)
    @pattern, @http_method, @controller_class, @action_name =
    pattern, http_method, controller_class, action_name
  end

  # checks if pattern matches path and method matches request method
  def matches?(req)
    path = req.path
    method = req.request_method.downcase.to_sym
    !!(path =~ @pattern) && @http_method == method
  end

  # use pattern to pull out route params (save for later?)
  # instantiate controller and call controller action
  def run(req, res)
    controller = @controller_class.new(req, res, route_params(req))
    controller.invoke_action(action_name)
  end

  def route_params(req)
    match_data = @pattern.match(req.path)
    match_data.names.each_with_object({}) do |name, r_params|
      r_params[name] = match_data[name]
    end
  end

end

class Router
  attr_reader :routes

  def initialize
    @routes = []
  end

  # simply adds a new route to the list of routes
  def add_route(pattern, method, controller_class, action_name)
    @routes << Route.new(pattern, method, controller_class, action_name)
  end

  # evaluate the proc in the context of the instance
  # for syntactic sugar :)
  def draw(&proc)
    instance_eval(&proc)
  end

  # make each of these methods that
  # when called add route
  [:get, :post, :put, :delete].each do |http_method|
    define_method(http_method) do |pattern, controller_class, action_name|
      add_route(pattern, http_method, controller_class, action_name)
    end
  end

  # should return the route that matches this request
  def match(req)
    @routes.find { |route| route.matches?(req) }
  end

  # either throw 404 or call run on a matched route
  def run(req, res)
    route = match(req)
    if route && authentic?(req)
      route.run(req, res)
    else
      res.status = 404
    end
  end


  def authentic?(req)
    if @req.request_method == "GET"
      return true
    elsif session[:auth_tokens].include?(
      @req.query["form_authenticity_token"]
      )
      return true
    else
      false
    end
  end

end
