require_relative './router/router.rb'
Dir["/app/controllers'/*.rb"].each {|file| require file }

router.draw do
  # get Regexp.new("^/cats$"), CatsController, :index
  # get Regexp.new("^/cats/(?<cat_id>\\d+)/statuses$"), StatusesController, :index
end
