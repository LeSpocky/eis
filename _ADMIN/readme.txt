How to build alpeis packages using Jenkins
==============================================================================

This document describes how the automated build of alpeis packages can be
performed using the continuous integration tool 'Jenkins' [1].

Steps to do:
------------------------------------------------------------------------------
1. Install Jenkins

2. Setup the following six build jobs:

2.1 '_alpeis__checkBuildJobs'
This job checks periodically if for every package on the repository the
corresponding build jobs exist. At the moment two jobs per package are
supportet, so you can build x86 and x86_64 versions of the packages.
Here the relevant settings for this job:
- Freestyle job
- Name: '_alpeis__checkBuildJobs'
- Restrict where this project can be run: 'master'
- VCS: 'Git' with proper repository URL
- Poll SCM: 'H 2 * * *' which means every day at around 2:??AM. This is
  special Jenkins syntax to spread the load.
- Build: 'Execute shell' with the command 'ADMIN/checkForNewPackages.sh'
- Add some notification Post-build actions if you like

2.2 'alpeis__TEMPLATE_x86' and 'alpeis__TEMPLATE_x86_64'
These are the two template jobs which will be used to generate new build jobs
if new packages where added to the repository. They are mostly identical with
one exception, see below.
Here the relevant settings for this job:
- Freestyle job
- Name: 'alpeis__TEMPLATE_x86' and 'alpeis__TEMPLATE_x86_64'
- Restrict where this project can be run
-- The x86-job on a 32bit build node
-- The x86_64-job on a 64bit build node
- VCS: 'Git' with proper repository URL
- No build triggers. These jobs will never run directly, they are templates.
- Build: 'Execute shell' with the following content:
----->8 nip 8<----------------
package='TEMPLATE'
cd $package
abuild checksum
abuild -r
rtc=$?
if [ "$rtc" = 0 ] ; then
    # The following line on the 32bit template:
    cp -f *.apk /data/ci/results/ci-results-alpeis/v2.4/x86
    # Or this line on the 64bit template:
    cp -f *.apk /data/ci/results/ci-results-alpeis/v2.4/x86_64
else
    exit $rtc
fi
----->8 nip 8<----------------
- Post-build action 'Build other project'
-- '_alpeis__updateRepoIndex_x86' on the 32bit template
-- '_alpeis__updateRepoIndex_x86_64' on the 64bit template
-- 'Trigger even if the build is unstable'
- Add some notification Post-build actions if you like

2.3 'alpeis__updateRepoIndex_x86' and 'alpeis__updateRepoIndex_x86_64'
Here the relevant settings for this job:
- Freestyle job
- Name: 'alpeis__updateRepoIndex_x86' and 'alpeis__updateRepoIndex_x86_64'
- Restrict where this project can be run
-- The x86-job on a 32bit build node
-- The x86_64-job on a 64bit build node
- VCS: 'None'
- Build trigger 'Build after other projects are built'. Will be filled
  automatically.
- Build: 'Execute shell' with the following content:
----->8 nip 8<----------------
# The following line on alpeis__updateRepoIndex_x86:
BASEARCH='/path/to/repo/v2.4/x86/'
# The following line on alpeis__updateRepoIndex_x86_64:
BASEARCH='/path/to/repo/v2.4/x86_64/'
HOMEDIR='/home/jenkins'
apk index -f -o $HOMEDIR/APKINDEX.unsigned.tar.gz -d eis $BASEARCH/*.apk
openssl dgst -sha1 -sign $HOMEDIR/.abuild/<your-alpine-buildkey>.rsa -out $HOMEDIR/.SIGN.RSA.<your-alpine-buildkey>.rsa.pub $HOMEDIR/APKINDEX.unsigned.tar.gz
tar -c $HOMEDIR/.SIGN.RSA.<your-alpine-buildkey>.rsa.pub | abuild-tar --cut | gzip -9 > $HOMEDIR/signature.tar.gz
cat $HOMEDIR/signature.tar.gz $HOMEDIR/APKINDEX.unsigned.tar.gz > $BASEARCH/APKINDEX.tar.gz
rm -f $HOMEDIR/signature.tar.gz
rm -f $HOMEDIR/APKINDEX.unsigned.tar.gz
rm -f $HOMEDIR/.SIGN.RSA.<your-alpine-buildkey>.rsa.pub
----->8 nip 8<----------------
- Add some notification Post-build actions if you like



[1] http://jenkins-ci.org
