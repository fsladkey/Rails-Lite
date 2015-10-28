require_relative './params'
require_relative './session'
require_relative './flash'

module ActionControllerLite
  class Base
    attr_reader :req, :res

    def initialize(req, res, route_params = {})
      @params = Params.new(req, route_params)
      @req = req
      @res = res
    end

    def session
      @session ||= Session.new(@req)
    end

    def flash
      @flash ||= Flash.new(@req)
    end

    def form_authenticity_token
      #I know this should probably not persist between sessions and should use similer system to flash...
      #also should encrypt session otherwise this is kind of pointless.
      form_authenticity_token = SecureRandom::urlsafe_base_64
      session[:auth_tokens] << form_authenticity_token
      form_authenticity_token
    end

    def invoke_action(name)
      self.send(name)
      render(name) unless already_built_response?
    end

    def redirect_to(url)
      raise StandardError if already_built_response?
      @already_built_response = true
      @res.header["location"] = url
      @res.status = 302
      session.store_session(@res)
      flash.store_session(@res)
    end


    def render_content(content, content_type)
      raise StandardError if already_built_response?
      @already_built_response = true
      @res.content_type = content_type
      @res.body = content
      session.store_session(@res)
      flash.store_session(@res)
    end

    def render(template_name)
      raise StandardError if already_built_response?
      content = File.readlines(file_path(template_name)).join
      render_content(ERB.new(content).result(binding) ,"text/html")
    end

    private

    def file_path(template_name)
      folder = self.class.name.underscore
      file_name = template_name.to_s + ".html.erb"
      file_path = "views/#{folder}/#{file_name}"
    end

    def already_built_response?
      @already_built_response
    end

  end
end
