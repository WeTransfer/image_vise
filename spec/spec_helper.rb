require 'bundler'
Bundler.require

require 'addressable/uri'
require 'strenv'
require 'tmpdir'
require_relative 'test_server'


TEST_RENDERS_DIR = Dir.mktmpdir

module Examine
  def examine_image(magick_image, name_tag = 'test-img')
    # When doing TDD, waiting for stuff to open is a drag - allow
    # it to be squelched using 2 envvars. Also viewing images
    # makes no sense on CI unless we bother with artifacts.
    # The first one is what Gitlab-CI sets for us.
    return if ENV.key?("CI_BUILD_ID")
    return if ENV.key?("SKIP_INTERACTIVE")

    Dir.mkdir(TEST_RENDERS_DIR) unless File.exist?(TEST_RENDERS_DIR)
    path = File.join(TEST_RENDERS_DIR, name_tag + '.png')
    magick_image.format = 'png'
    magick_image.write(path)
    `open #{path}`
  end

  def examine_image_from_string(string)
    # When doing TDD, waiting for stuff to open is a drag - allow
    # it to be squelched using 2 envvars. Also viewing images
    # makes no sense on CI unless we bother with artifacts.
    # The first one is what Gitlab-CI sets for us.
    return if ENV.key?("CI_BUILD_ID")
    return if ENV.key?("SKIP_INTERACTIVE")

    Dir.mkdir(TEST_RENDERS_DIR) unless File.exist?(TEST_RENDERS_DIR)
    random_name = 'test-image-%s' % SecureRandom.hex(3)
    path = File.join(TEST_RENDERS_DIR, random_name)
    File.open(path, 'wb'){|f| f << string }
    `open #{path}`
  end
end

require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require_relative '../lib/image_vise'

RSpec.configure do | config |
  config.order = 'random'
  config.include Examine
  config.before :suite do
    TestServer.start(nil, ssl=false, port=9001)
  end

  config.after :each do
    ImageVise.reset_allowed_hosts!
    ImageVise.reset_secret_keys!
  end

  config.after :suite do
    sleep 2
    FileUtils.rm_rf(TEST_RENDERS_DIR)
  end

  def test_image_path
    File.expand_path(__dir__ + '/waterside_magic_hour.jpg')
  end

  def test_image_path_psd
    File.expand_path(__dir__ + '/waterside_magic_hour.psd')
  end

  def test_image_path_tif
    File.expand_path(__dir__ + '/waterside_magic_hour_gray.tif')
  end

  def test_image_adobergb_path
    File.expand_path(__dir__ + '/waterside_magic_hour_adobergb.jpg')
  end

  def test_image_png_transparency
    File.expand_path(__dir__ + '/waterside_magic_hour_transp.png')
  end

  def public_url
    'http://localhost:9001/waterside_magic_hour.jpg'
  end

  def public_url_psd
    'http://localhost:9001/waterside_magic_hour.psd'
  end

  def public_url_psd_multilayer
    'http://localhost:9001/layers-with-blending.psd'
  end

  def public_url_tif
    'http://localhost:9001/waterside_magic_hour_gray.tif'
  end

  def public_url_png_transparency
    'http://localhost:9001/waterside_magic_hour_transp.png'
  end

  config.around :each do |e|
    STRICT_ENV.with_protected_env { e.run }
  end
end
