require 'webrick'


module Phase4
  class Flash
    attr_accessor :now

    def initialize(req)
      json_cookie = req.cookies.find do |cookie|
        cookie.name == '_rails_lite_app_flash'
      end
      @now = json_cookie ? JSON.parse(json_cookie.value) : {}
      @later = {}
    end

    def [](key)
      @now[key]
    end

    def []=(key, val)
      @now[key] = val
      @later[key] = val
    end


    def store_session(res)
      new_cookie = WEBrick::Cookie.new(
        '_rails_lite_app_flash',
        @later.to_json
      )
      new_cookie.path = '/'
      res.cookies << new_cookie
    end
  end
end
