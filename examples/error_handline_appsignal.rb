# Anywhere in your app code
module ImageViseAppsignal
  ImageVise::RenderEngine.prepend self

  def setup_error_handling(rack_env)
    txn = Appsignal::Transaction.current
    txn.set_action('%s#%s' % [self.class, 'call'])
  end

  def handle_request_error(err)
    Appsignal.add_exception(err)
  end

  def handle_generic_error(err)
    Appsignal.add_exception(err)
  end
end

# In config.ru
map '/thumbnails' do
  use Appsignal::Rack::GenericInstrumentation
  run ImageVise
end