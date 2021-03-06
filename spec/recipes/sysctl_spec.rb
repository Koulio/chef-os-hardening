# encoding: UTF-8
#
# Copyright 2014, Deutsche Telekom AG
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

describe 'os-hardening::sysctl' do
  context 'intel' do
    cached(:intel_run) do
      ChefSpec::ServerRunner.new do |node|
        node.normal['sysctl']['conf_dir'] = '/etc/sysctl.d'
        node.normal['cpu']['0']['vendor_id'] = 'GenuineIntel'
      end.converge(described_recipe)
    end

    describe 'attributes' do
      subject { intel_run.node['os-hardening']['security']['cpu_vendor'] }

      it 'should detect intel cpu' do
        is_expected.to eq('intel')
      end
    end

    describe 'chef run' do
      subject { intel_run }

      it 'creates /etc/sysctl.conf' do
        is_expected.to create_file('/etc/sysctl.conf').with(
          user: 'root',
          group: 'root',
          mode: 0440
        )
      end

      it 'not write log for cpu_vendor fallback' do
        is_expected.to_not write_log(
          'WARNING: Could not properly determine the cpu vendor. Fallback to ' \
            'intel cpu.'
        ).with(
          level: :warn
        )
      end
    end
  end

  context 'amd' do
    cached(:amd_run) do
      ChefSpec::ServerRunner.new do |node|
        node.normal['sysctl']['conf_dir'] = '/etc/sysctl.d'
        node.normal['cpu']['0']['vendor_id'] = 'AuthenticAMD'
      end.converge(described_recipe)
    end

    describe 'attributes' do
      subject { amd_run.node['os-hardening']['security']['cpu_vendor'] }

      it 'should detect amd cpu' do
        is_expected.to eq('amd')
      end
    end

    describe 'chef run' do
      subject { amd_run }

      it 'creates /etc/sysctl.conf' do
        is_expected.to create_file('/etc/sysctl.conf').with(
          user: 'root',
          group: 'root',
          mode: 0440
        )
      end

      it 'not write log for cpu_vendor fallback' do
        is_expected.to_not write_log(
          'WARNING: Could not properly determine the cpu vendor. Fallback to ' \
            'intel cpu.'
        ).with(
          level: :warn
        )
      end
    end
  end

  context 'fallback' do
    cached(:fallback_run) do
      ChefSpec::ServerRunner.new do |node|
        node.normal['sysctl']['conf_dir'] = '/etc/sysctl.d'
      end.converge(described_recipe)
    end

    describe 'attributes' do
      subject { fallback_run.node['os-hardening']['security']['cpu_vendor'] }

      it 'should detect intel cpu' do
        is_expected.to eq('intel')
      end
    end

    describe 'chef run' do
      subject { fallback_run }

      it 'creates /etc/sysctl.conf' do
        is_expected.to create_file('/etc/sysctl.conf').with(
          user: 'root',
          group: 'root',
          mode: 0440
        )
      end

      it 'not write log for cpu_vendor fallback' do
        is_expected.to write_log(
          'WARNING: Could not properly determine the cpu vendor. Fallback to ' \
            'intel cpu.'
        ).with(
          level: :warn
        )
      end
    end
  end

  describe 'sysctl flags' do
    let(:ipv6_enable) { false }
    let(:network_forwarding) { false }
    let(:arp_restricted) { true }
    let(:enable_module_loading) { true }
    let(:enable_sysrq) { true }
    let(:enable_core_dump) { true }
    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        node.normal['os-hardening']['network']['forwarding'] =
          network_forwarding
        node.normal['os-hardening']['network']['ipv6']['enable'] = ipv6_enable
        node.normal['os-hardening']['network']['arp']['restricted'] =
          arp_restricted
        node.normal['os-hardening']['security']['kernel']['enable_module_loading'] = # rubocop:disable Metrics/LineLength
          enable_module_loading
        node.normal['os-hardening']['security']['kernel']['enable_sysrq'] =
          enable_sysrq
        node.normal['os-hardening']['security']['kernel']['enable_core_dump'] =
          enable_core_dump
      end.converge(described_recipe)
    end

    describe 'IPv4 forwarding' do
      subject do
        chef_run.node['sysctl']['params']['net']['ipv4']['ip_forward']
      end

      context 'when forwarding is enabled' do
        let(:network_forwarding) { true }

        it 'should enable IPv4 forwarding in sysctl attributes' do
          is_expected.to eq(1)
        end
      end

      context 'when forwarding is disabled' do
        let(:network_forwarding) { false }

        it 'should disable IPv4 forwarding in sysctl attributes' do
          is_expected.to eq(0)
        end
      end
    end

    describe 'IPv6 forwarding' do
      RSpec.shared_examples 'IPv6 forwarding in sysctl attributes' do |state|
        subject { chef_run.node['sysctl']['params']['net']['ipv6']['conf']['all']['forwarding'] } # rubocop:disable Metrics/LineLength

        it "should #{state == 1 ? 'enable' : 'disable'} IPv6 forwarding in sysctl attributes" do # rubocop:disable Metrics/LineLength
          is_expected.to eq(state)
        end
      end

      context 'when IPv6 is enabled' do
        let(:ipv6_enable) { true }

        context 'when forwarding is enabled' do
          let(:network_forwarding) { true }

          include_examples 'IPv6 forwarding in sysctl attributes', 1
        end
        context 'when forwarding is disabled' do
          let(:network_forwarding) { false }

          include_examples 'IPv6 forwarding in sysctl attributes', 0
        end
      end

      context 'when IPv6 is disabled' do
        let(:ipv6_enable) { false }

        context 'when forwarding is enabled' do
          let(:network_forwarding) { true }

          include_examples 'IPv6 forwarding in sysctl attributes', 0
        end

        context 'when forwarding is disabled' do
          let(:network_forwarding) { false }

          include_examples 'IPv6 forwarding in sysctl attributes', 0
        end
      end
    end

    describe 'Control IPv6' do
      subject do
        chef_run.
          node['sysctl']['params']['net']['ipv6']['conf']['all']['disable_ipv6']
      end

      context 'when IPv6 is enabled' do
        let(:ipv6_enable) { true }

        it 'should not disable IPv6' do
          is_expected.to eq(0)
        end
      end

      context 'when IPv6 is disabled' do
        let(:ipv6_enable) { false }

        it 'should not disable IPv6' do
          is_expected.to eq(1)
        end
      end
    end

    describe 'ARP restrictions' do
      RSpec.shared_examples 'ARP restrictions in sysctl attributes' do |arp_ignore, arp_announce| # rubocop:disable Metrics/LineLength
        describe 'arp_ignore' do
          subject do
            chef_run.node['sysctl']['params']['net']['ipv4']['conf']['all']['arp_ignore'] # rubocop:disable Metrics/LineLength
          end

          it "should be set to #{arp_ignore}" do
            is_expected.to eq(arp_ignore)
          end
        end

        describe 'arp_announce' do
          subject do
            chef_run.node['sysctl']['params']['net']['ipv4']['conf']['all']['arp_announce'] # rubocop:disable Metrics/LineLength
          end

          it "should be set to #{arp_announce}" do
            is_expected.to eq(arp_announce)
          end
        end
      end

      context 'when ARP is restricted' do
        let(:arp_restricted) { true }

        include_examples 'ARP restrictions in sysctl attributes', 1, 2
      end

      context 'when ARP is not restricted' do
        let(:arp_restricted) { false }

        include_examples 'ARP restrictions in sysctl attributes', 0, 0
      end
    end

    describe 'Module loading' do
      subject do
        chef_run.node['sysctl']['params']['kernel']['modules_disabled']
      end

      context 'when module loading is enabled' do
        let(:enable_module_loading) { true }

        it 'should not set the sysctl flag' do
          is_expected.to eq(nil)
        end

        describe 'rebuild of initramfs' do
          subject { chef_run }

          it 'should not create initramfs module file' do
            is_expected.not_to create_template('/etc/initramfs-tools/modules')
          end

          it 'should not rebuild initramfs' do
            is_expected.not_to run_execute('update-initramfs')
          end
        end
      end

      context 'when module loading is disabled' do
        let(:enable_module_loading) { false }

        it 'should disable module loading via sysctl flag' do
          is_expected.to eq(1)
        end

        describe 'rebuild of initramfs' do
          subject { chef_run }

          it 'should create initramfs module file' do
            is_expected.to create_template('/etc/initramfs-tools/modules')
          end

          it 'should rebuild initramfs' do
            is_expected.to run_execute('update-initramfs')
          end
        end
      end
    end

    describe 'Control magic SysRq' do
      subject do
        chef_run.node['sysctl']['params']['kernel']['sysrq']
      end

      context 'when sysrq is enabled' do
        let(:enable_sysrq) { true }

        it 'should enable sysrq with safe value' do
          is_expected.to eq(244)
        end
      end

      context 'when sysrq is disabled' do
        let(:enable_sysrq) { false }

        it 'should disable sysrq' do
          is_expected.to eq(0)
        end
      end
    end

    describe 'Core dumps with SUID' do
      subject do
        chef_run.node['sysctl']['params']['fs']['suid_dumpable']
      end

      context 'when core dumps are enabled' do
        let(:enable_core_dump) { true }

        it 'should set suid_dumpable to safe value' do
          is_expected.to eq(2)
        end
      end

      context 'when core dumps are disabled' do
        let(:enable_core_dump) { false }

        it 'should set suid_dumpable to default value' do
          is_expected.to eq(0)
        end
      end
    end
  end
end
