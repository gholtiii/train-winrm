# rubocop: disable Metrics/BlockLength

# author: Christoph Hartmann
# author: Dominik Richter

require "minitest/autorun"
require "train"
require "byebug"
require "logger"

class Minitest::Spec
  def self.it_passes_shared_tests(&block)
    it "verify os" do
      os = conn.os
      _(os[:name]).must_equal "windows_server_2016_standard_evaluation"
      _(os[:family]).must_equal "windows"
      _(os[:release]).must_equal "10.0.14393"
      _(os[:arch]).must_equal "x86_64"
    end

    it "run echo test" do
      cmd = conn.run_command('Write-Output "test"')
      _(cmd.stdout).must_equal "test\r\n"
      _(cmd.stderr).must_equal ""
    end

    it "use powershell piping" do
      cmd = conn.run_command("New-Object -Type PSObject | Add-Member -MemberType NoteProperty -Name A -Value (Write-Output 'PropertyA') -PassThru | Add-Member -MemberType NoteProperty -Name B -Value (Write-Output 'PropertyB') -PassThru | ConvertTo-Json")
      _(cmd.stdout).must_equal "{\r\n    \"A\":  \"PropertyA\",\r\n    \"B\":  \"PropertyB\"\r\n}\r\n"
      _(cmd.stderr).must_equal ""
    end

    describe "using remote files" do
      before do
        @remote_path = "train-winrm-test-" + rand(100000).to_s + ".txt"
      end

      let(:remote_file) do
        conn.run_command("New-Item -Path . -Name \"#{@remote_path}\" -ItemType \"file\" -Value \"hello world\"")
        conn.file(@remote_path)
      end

      it "exists" do
        _(remote_file.exist?).must_equal(true)
      end

      it "is a file" do
        _(remote_file.file?).must_equal(true)
      end

      it "has type :file" do
        _(remote_file.type).must_equal(:file)
      end

      it "has content" do
        # TODO: this shouldn't include newlines that aren't in the original file
        _(remote_file.content).must_equal("hello world\r\n")
      end

      it "has owner name" do
        _(remote_file.owner).wont_be_nil
      end

      it "has no group name" do
        _(remote_file.group).must_be_nil
      end

      it "has no mode" do
        _(remote_file.mode).must_be_nil
      end

      it "has no modified time" do
        _(remote_file.mtime).must_be_nil
      end

      it "has size" do
        _(remote_file.size).wont_be_nil
      end

      it "has size 11" do
        _(remote_file.size).must_equal 11
      end

      it "has no selinux_label handling" do
        _(remote_file.selinux_label).must_be_nil
      end

      it "has product_version" do
        _(remote_file.product_version).wont_be_nil
      end

      it "has file_version" do
        _(remote_file.file_version).wont_be_nil
      end

      it "returns nil for mounted" do
        _(remote_file.mounted).must_be_nil
      end

      it "has no link_path" do
        _(remote_file.link_path).must_be_nil
      end

      it "has no uid" do
        _(remote_file.uid).must_be_nil
      end

      it "has no gid" do
        _(remote_file.gid).must_be_nil
      end

      it "provides a json representation" do
        j = remote_file.to_json
        _(j).must_be_kind_of Hash
        _(j["type"]).must_equal :file
      end

      after do
        conn.run_command("Remove-Item -Path \"#{@remote_path}\"")
      end
    end

    describe "hashing methods" do
      before do
        @remote_path = "train-winrm-hash-test-" + rand(100000).to_s + ".txt"
      end

      let(:remote_file) do
        conn.run_command("New-Item -Path . -Name \"#{@remote_path}\" -ItemType \"file\" -Value \"easy to hash\"")
        conn.file(@remote_path)
      end

      it "has the correct md5sum" do
        _(remote_file.md5sum).must_equal "c15b41ade1221a532a38d89671ffaa20"
      end

      it "has the correct sha256sum" do
        _(remote_file.sha256sum).must_equal "24ae25354d5f697566e715cd46e1df2f490d0b8367c21447962dbf03bf7225ba"
      end

      after do
        conn.run_command("Remove-Item -Path \"#{@remote_path}\"")
      end
    end

    describe "a file with whitespace in the path" do
      before do
        # This is just being used to generate a randomized path
        @local_file = Tempfile.new("foo bar")
      end

      let(:remote_file) do
        file =  conn.file(@local_file.path)
        file
      end

      it "provides the full path with whitespace" do
        # No implication that it exists
        _(remote_file.path).must_equal @local_file.path
      end

      it "returns basename of file" do
        # Since remote_file is Train::Remote::File::Windows, the separator would default to "\\".  We need to provide it explicitly here since we're using Unix paths.
        basename = ::File.basename(@local_file.path)
        _(remote_file.basename(nil, "/")).must_equal basename
      end

      after do
        @local_file.close
        @local_file.unlink
      end
    end

    after do
      # close the connection
      conn.close
    end
  end
end

describe "windows winrm command" do
  describe "When using user and password" do
    let(:conn) do
      logger = Logger.new(STDERR, level: (ENV["TRAIN_WINRM_LOGLEVEL"] || :info))

      # get final config
      target_config = Train.target_config(
        target: ENV["TRAIN_WINRM_TARGET"],
        password: ENV["TRAIN_WINRM_PASSWORD"],
        ssl: ENV["TRAIN_WINRM_SSL"],
        self_signed: true,
        logger: logger,
        port: 55986,
        winrm_shell_type: ENV["TRAIN_WINRM_SHELL_TYPE"] || "powershell"
      )

      # initialize train
      backend = Train.create("winrm", target_config)

      # start or reuse a connection
      conn = backend.connection
      conn
    end

    it_passes_shared_tests
  end

  describe "When using certificates" do
    let(:conn) do
      logger = Logger.new(STDERR, level: (ENV["TRAIN_WINRM_LOGLEVEL"] || :info))

      # get final config
      target_config = Train.target_config(
        target: ENV["TRAIN_WINRM_TARGET"],
        ssl: true,
        self_signed: true,
        logger: logger,
        port: 55986,
        client_cert: ::File.join(::File.dirname(__FILE__), "./fixtures/.openssl/user.pem"),
        client_key: ::File.join(::File.dirname(__FILE__), "./fixtures/.openssl/key.pem"),
        winrm_shell_type: ENV["TRAIN_WINRM_SHELL_TYPE"] || "powershell"
      )

      # initialize train
      backend = Train.create("winrm", target_config)

      # start or reuse a connection
      conn = backend.connection
      conn
    end

    it_passes_shared_tests
  end
end
