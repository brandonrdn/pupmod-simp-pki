require 'spec_helper_acceptance'

test_name 'pki_windows_sync'

describe 'pki_windows_sync' do

  windows = hosts_with_role(hosts, 'windows')
  windows.each do |win|

    let(:manifest) { <<-EOS
    class { 'pki':}
                     EOS
    }

    context 'default parameters' do

      it 'should work with no errors' do 
        apply_manifest_on(win, manifest, :catch_failures => true, :acceptable_exit_codes => [0,2])
      end

      it 'should be idempotent' do
        apply_manifest_on(win, manifest, :catch_changes => true)
      end

      describe file('C:\ProgramData\SIMP\pki') do
        it { should be_directory }
      end

      describe file('C:\ProgramData\SIMP') do
        it { should be_grouped_into 'Administrators' }
        it { should be_owned_by 'Administrator' }
      end

    end
  end
end

