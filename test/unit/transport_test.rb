# rubocop: disable Metrics/BlockLength

require_relative "./helper"
require "train-winrm/transport"
require "logger"

describe "winrm transport" do
  let(:cls) do
    plat = Train::Platforms.name("mock").in_family("windows")
    plat.add_platform_methods
    Train::Platforms::Detect.stubs(:scan).returns(plat)
    TrainPlugins::WinRM::Transport
  end
  let(:conf) do
    {
      host: rand.to_s,
      password: rand.to_s,
      logger: Logger.new(STDERR, level: :info),
    }
  end
  let(:cls_agent) { cls.new({ host: rand.to_s, logger: Logger.new(STDERR, level: :info) }) }

  describe "default options" do
    let(:winrm) { cls.new({ host: "dummy", logger: Logger.new(STDERR, level: :info) }) }

    it "can be instantiated (with valid config)" do
      _(winrm).wont_be_nil
    end

    it "configures the host" do
      _(winrm.options[:host]).must_equal "dummy"
    end

    it "has default endpoint" do
      _(winrm.options[:endpoint]).must_be_nil
    end

    it "has default path set" do
      _(winrm.options[:path]).must_equal "/wsman"
    end

    it "has default ssl set" do
      _(winrm.options[:ssl]).must_equal false
    end

    it "has default self_signed set" do
      _(winrm.options[:self_signed]).must_equal false
    end

    it "has default client_cert set" do
      _(winrm.options[:client_cert]).must_be_nil
    end

    it "has default client key set" do
      _(winrm.options[:client_key]).must_be_nil
    end

    it "has default rdp_port set" do
      _(winrm.options[:rdp_port]).must_equal 3389
    end

    it "has default winrm_transport set" do
      _(winrm.options[:winrm_transport]).must_equal :negotiate
    end

    it "has default winrm_disable_sspi set" do
      _(winrm.options[:winrm_disable_sspi]).must_equal false
    end

    it "has default winrm_basic_auth_only set" do
      _(winrm.options[:winrm_basic_auth_only]).must_equal false
    end

    it "has default user" do
      _(winrm.options[:user]).must_equal "administrator"
    end
  end

  describe "winrm options" do
    let(:winrm) { cls.new(conf) }
    let(:connection) { winrm.connection }
    it "without ssl generates uri" do
      conf[:host] = "dummy_host"
      _(connection.uri).must_equal "winrm://administrator@http://dummy_host:5985/wsman:3389"
    end

    it "with ssl generates uri" do
      conf[:ssl] = true
      conf[:host] = "dummy_host_ssl"
      _(connection.uri).must_equal "winrm://administrator@https://dummy_host_ssl:5986/wsman:3389"
    end

    it "with ssl and certs generates uri" do
      conf[:ssl] = true
      conf[:host] = "dummy_host_ssl"
      conf[:client_cert] = "/tmp/whatever"
      conf[:client_key] = "/tmp/whatever.pem"
      _(connection.uri).must_equal "winrm://https://dummy_host_ssl:5986/wsman:3389"
    end
  end

  describe "options validation" do
    let(:winrm) { cls.new(conf) }
    it "raises an error when a non-supported winrm_transport is specified" do
      conf[:winrm_transport] = "invalid"
      _(proc { winrm.connection }).must_raise Train::ClientError
    end
  end
end
