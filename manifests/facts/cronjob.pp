# == Class: mcollective::facts
#
# This module installs a cron script that puts Puppet facts in a file for MCollective to use
#
# === Example
#
# Hiera: 
#   mcollective::facts::cronjob::run_every: 15   # every quarter hour 
#
class mcollective::facts::cronjob(
  $run_every = 'unknown',
)
inherits mcollective {

  # if they passed in Hiera value use that.
  $enable = $run_every ? {
    'unknown' => 'absent',
    undef     => 'absent',
    ''        => 'absent',
    default   => 'present',
  }

  # shorten for ease of use
  $yamlfile = "${mcollective::etcdir}/facts.yaml"

  case $::osfamily {
    'Windows': {
      $windowspath = regsubst($mcollective::etcdir, '/', '\\\\\\', 'G')

      $file = $enable ? {
        'present' => 'file',
        default   => 'absent',
      }
      file { "${mcollective::etcdir}/refresh-mcollective-metadata.bat":
        ensure  => $file,
        owner   => 'Administrators',
        group   => 'Administrators',
        mode    => '0555',
        replace => true,
        content => template('mcollective/refresh-mcolletive-metadata.bat.erb'),
      }
      file { "${mcollective::etcdir}/refresh-mcollective-metadata.rb":
        ensure  => $file,
        owner   => 'Administrators',
        group   => 'Administrators',
        mode    => '0555',
        replace => true,
        content => template('mcollective/refresh-mcollective-metadata.rb.erb'),
      }
      scheduled_task { 'mcollective-facts':
        ensure  => $enable,
        command => "${windowspath}\\refresh-mcollective-metadata.bat",
        trigger => {
          schedule         => daily,
          start_time       => '00:00',
          minutes_interval => $run_every,
          minutes_duration => $run_every + 1,
        },
        require => [
          File["${mcollective::etcdir}/refresh-mcollective-metadata.rb"],
          File["${mcollective::etcdir}/refresh-mcollective-metadata.bat"]
        ]
      }
    }
    default: {
      # Define the minute to be all if runevery wasn't defined
      $minute = $enable ? {
        'absent'  => '*',
        'present' => "*/${run_every}",
      }
      cron { 'mcollective-facts':
        ensure  => $enable,
        command => "facter --puppet --yaml > ${yamlfile}.new && ! diff -q ${yamlfile}.new ${yamlfile} > /dev/null && mv -f ${yamlfile}.new ${yamlfile}",
        minute  => $minute,
      }
    }
  }
}
