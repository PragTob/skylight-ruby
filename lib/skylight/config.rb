require 'yaml'

module Skylight
  class Config

    # Map environment variable keys with Skylight configuration keys
    ENV_TO_KEY = {
      'SK_APPLICATION'       => :'application',
      'SK_AUTHENTICATION'    => :'authentication',
      'SK_AGENT_INTERVAL'    => :'agent.interval',
      'SK_AGENT_KEEPALIVE'   => :'agent.keepalive',
      'SK_AGENT_SAMPLE_SIZE' => :'agent.sample',
      'SK_REPORT_HOST'       => :'report.host',
      'SK_REPORT_PORT'       => :'report.port',
      'SK_REPORT_SSL'        => :'report.ssl',
      'SK_REPORT_DEFLATE'    => :'report.deflate' }

    # Default values for Skylight configuration keys
    DEFAULTS = {
      :'agent.keepalive' => 60,
      :'agent.interval'  => 5,
      :'agent.sample'    => 200,
      :'report.host'     => 'agent.skylight.io'.freeze,
      :'report.port'     => 443,
      :'report.ssl'      => true,
      :'report.deflate'  => true }.freeze

    def self.load(path = nil, environment = nil, env = ENV)
      attrs = {}

      if path
        attrs = YAML.load_file(path)
      end

      if env
        attrs[:priority] = remap_env(env)
      end

      new(environment, attrs)
    end

    def self.load_from_env(env = ENV)
      self.load(nil, nil, env)
    end

    def self.remap_env(env)
      ret = {}

      env.each do |k, val|
        if key = ENV_TO_KEY[k]
          ret[key] =
            case val
            when /^false$/i      then false
            when /^true$/i       then true
            when /^(nil|null)$/i then nil
            when /^\d+$/         then val.to_i
            when /^\d+\.\d+$/    then val.to_f
            else val
            end
        end
      end if env

      ret
    end

    def initialize(*args)
      attrs = {}

      if Hash === args.last
        attrs = args.pop
      end

      @values   = {}
      @priority = {}
      @regexp   = nil

      p = attrs.delete(:priority)

      if @environment = args[0]
        @regexp = /^#{Regexp.escape(@environment)}\.(.+)$/
      end

      attrs.each do |k, v|
        self[k] = v
      end

      if p
        p.each do |k, v|
          @priority[k.to_sym] = v
        end
      end
    end

    def get(key, default = nil, &blk)
      key = key.to_sym

      return @priority[key] if @priority.key?(key)
      return @values[key]   if @values.key?(key)
      return DEFAULTS[key]  if DEFAULTS.key?(key)

      if default
        return default
      elsif blk
        return blk.call(key)
      end

      nil
    end

    alias [] get

    def set(key, val, scope = nil)
      if scope
        key = [scope, key].join('.')
      end

      if Hash === val
        val.each do |k, v|
          set(k, v, key)
        end
      else
        if @regexp && key =~ @regexp
          @priority[$1.to_sym] = val
        end

        @values[key.to_sym] = val
      end
    end

    alias []= set

    def to_env
      ret = {}

      ENV_TO_KEY.each do |k, v|
        if (c = get(v)) != DEFAULTS[v]
          ret[k] = cast_for_env(c)
        end
      end

      ret
    end

    #
    #
    # ===== Helpers =====
    #
    #

    def worker
      Worker::Builder.new(self)
    end

    def gc
      GC.new(get('gc.profiler', GC::Profiler))
    end

  private

    def cast_for_env(v)
      case v
      when true  then 'true'
      when false then 'false'
      when nil   then 'nil'
      else v.to_s
      end
    end

  end
end