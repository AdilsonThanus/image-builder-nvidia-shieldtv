require 'serverspec'
set :backend, :exec

describe "Root filesystem" do
  let(:rootfs_path) { return '/build' }

  it "exists" do
    rootfs_dir = file(rootfs_path)

    expect(rootfs_dir).to exist
  end

  context "Hypriot OS Release in /etc/os-release" do
    let(:stdout) { command("cat #{rootfs_path}/etc/os-release").stdout }

    it "has a HYPRIOT_OS= entry" do
      expect(stdout).to contain('^HYPRIOT_OS=')
    end
    it "has a HYPRIOT_TAG= entry" do
      expect(stdout).to contain('^HYPRIOT_TAG=')
    end
    it "has a HYPRIOT_DEVICE= entry" do
      expect(stdout).to contain('^HYPRIOT_DEVICE=')
    end

    it "is for architecure 'HYPRIOT_OS=\"HypriotOS/arm64\"'" do
      expect(stdout).to contain('^HYPRIOT_OS="HypriotOS/arm64"$')
    end

    it "is for device 'HYPRIOT_DEVICE=\"NVIDIA ShieldTV\"'" do
      expect(stdout).to contain('^HYPRIOT_DEVICE="NVIDIA ShieldTV"$')
    end

  end
end
