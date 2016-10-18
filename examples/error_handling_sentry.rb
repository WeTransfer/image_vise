# Anywhere in your app code
module ImageViseSentrySupport
  ImageVise::RenderEngine.prepend self

  def setup_error_handling(rack_env)
    @env = rack_env
  end

  def handle_request_error(err)
    @env['rack.exception'] = err
  end

  def handle_generic_error(err)
    @env['rack.exception'] = err
  end
end

# In config.ru
Raven.configure do |config|
  config.dsn = 'https://secretoken@app.getsentry.com/1234567'
end
use Raven::Rack
map '/thumbnails' do
  run ImageVise
end
