require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
require 'beaker-rspec/spec_helper'
require 'beaker-rspec/helpers/serverspec'
include Simp::BeakerHelpers
require 'winrm'

unless ENV['BEAKER_provision'] == 'no'

  hosts.each do |host|
    case host['platform']
    when /windows/

      GEOTRUST_GLOBAL_CA = <<-EOM.freeze
  -----BEGIN CERTIFICATE-----
  MIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT
  MRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i
  YWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcNMjIwNTIxMDQwMDAwWjBCMQswCQYDVQQG
  EwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UEAxMSR2VvVHJ1c3Qg
  R2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9
  9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdq
  fnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDv
  iS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6cJmTM386DGXHKTubU
  1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmRCw7+OC7RHQWa9k0+
  bw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW
  MPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTA
  ephojYn7qwVkDBF9qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1l
  uMrMTjANBgkqhkiG9w0BAQUFAAOCAQEANeMpauUvXVSOKVCUn5kaFOSPeCpilKIn
  Z57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz/Tt1kL/6cdjHPTfS
  tQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF
  PseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Un
  hw4EbNX/3aBd7YdStysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV
  5fEWCRE11azbJHFwLJhWC9kXtNHjUStedejV0NxPNO3CBWaAocvmMw==
  -----END CERTIFICATE-----
      EOM

      install_puppet_agent_on(host, options)
      install_cert_on_windows(host, 'geotrustglobal', GEOTRUST_GLOBAL_CA)
      on host, puppet('module', 'install', 'puppetlabs-stdlib')
      on host, puppet('module', 'install', 'simp-simplib')
      on host, puppet('module', 'install', 'simp-auditd')

    else
      # Install Puppet
      if host.is_pe?
        install_pe
      else
        install_puppet
      end
    end

    RSpec.configure do |c|
      c.host = host

      if host['platform'] =~ /windows/
        proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

        c.formatter = :documentation

        c.before :suite do
          path = File.expand_path(File.dirname(__FILE__) + '/../').split('/')
          name = path[path.length - 1].split('-')[1]
          # Install module and dependencies
          puppet_module_install(source: proj_root, module_name: name)
        end

      else    
        # ensure that environment OS is ready on each host
        fix_errata_on hosts

        # Readable test descriptions
        c.formatter = :documentation

        # Configure all nodes in nodeset
        c.before :suite do
          begin
            # Install modules and dependencies from spec/fixtures/modules
            copy_fixture_modules_to( hosts )
            begin
              server = only_host_with_role(hosts, 'server')
            rescue ArgumentError =>e
              server = only_host_with_role(hosts, 'default')
            end

            # Generate and install PKI certificates on each SUT
            Dir.mktmpdir do |cert_dir|
              run_fake_pki_ca_on(server, hosts, cert_dir )
              hosts.each{ |sut| copy_pki_to( sut, cert_dir, '/etc/pki/simp-testing' )}
            end

            # add PKI keys
            copy_keydist_to(server)
          rescue StandardError, ScriptError => e
            if ENV['PRY']
              require 'pry'; binding.pry
            else
              raise e
            end
          end
        end
      end
    end
  end
end
