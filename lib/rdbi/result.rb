class RDBI::Result
  extend MethLab
  include Enumerable

  attr_reader :schema
  attr_reader :sth
  attr_reader :driver
  attr_reader :rows

  def binds
    @binds.dup
  end

  # FIXME async
  inline(:complete, :complete?) { true } 

  inline(:eof, :eof?)           { @index >= @data.size }
  inline(:has_data, :has_data?) { @data.size > 0 }

  def initialize(data, schema, sth, binds)
    @schema       = schema
    @data         = data
    @rows         = data.size
    @sth          = sth
    @binds        = binds
    @index        = 0
    @mutex        = Mutex.new
    @driver       = RDBI::Result::Driver::Array
    @fetch_handle = nil 
    as(@driver)
  end

  def each
    @data.each { |x| yield x }
  end

  def rewind
    @index = 0
  end

  def as(driver, *args)
    # FIXME consistent class logic with RDBI.connect
    @driver       = driver
    @fetch_handle = driver.new(self, *args) 
  end

  # XXX after some thought, I really don't like this facade approach. Maybe we
  # just want to hand them an inheriting result.
  def fetch(row_count, driver=nil, *args)
    if driver
      as(driver, *args)
    end

    driver.fetch(row_count)
  end

  alias read fetch

  def raw_fetch(row_count)
    if row_count == :all
      return @data.dup
    else
      res = @data[@index..(@index + row_count)]
      @index += row_count
      return res
    end
  end

  def finish
    @data   = nil
    @sth    = nil
    @driver = nil
    @binds  = nil
  end
end

class RDBI::Result::Driver
  def initialize(result, *args)
    @result = result
    @result.rewind
  end

  def fetch(*args)
    @result.raw_fetch(*args)
  end
end

# standard array driver.
class RDBI::Result::Driver::Array < RDBI::Result::Driver
  # FIXME type conversion
  def fetch(row_count)
    @result.raw_fetch(row_count)
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
