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
    end
  end
end

