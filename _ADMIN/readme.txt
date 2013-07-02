How to build eisfair-ng packages using Jenkins
==============================================================================

This document describes how the automated build of eisfair-ng packages can be
performed using the continuous integration tool 'Jenkins' [1].

Steps to do:
------------------------------------------------------------------------------
1. Install Jenkins

2. Setup the following build jobs:

2.1 '_eisfair-ng__checkBuildJobs'
This job checks periodically if for every package on the repository the
corresponding build jobs exist. The job determines all template jobs and
creates build jobs for all packages based on them if necessary.
Here the relevant settings for this job:
- Freestyle job
- Name: '_eisfair-ng__checkBuildJobs'
- Restrict where this job can be executed to 'master'
- VCS: 'Git' with proper repository URL
- Poll SCM: 'H 2 * * *' which means every day at around 2:??AM. This is
  special Jenkins syntax to spread the load.
- Build: 'Execute shell' with the command 'ADMIN/checkForNewPackages.sh'
- Add some notification Post-build actions if you like

2.2 Template jobs for the different build targets
These are the template jobs which will be used to generate new build jobs if
new packages where added to the repository. They are mostly identical with
some minor exceptions, see below.
Here the relevant settings for these jobs:
- Freestyle job
- Names i. e. '_eisfair-ng__TEMPLATE__v2.6_x86' or '_eisfair-ng__TEMPLATE__v2.6_x86_64'
- Restrict where this jobs can be executed
-- v2.6-job on a build node based on alpine linux v2.6 a.s.o.
-- x86-job on a 32bit build node, x86_64-job on a 64bit build node a.s.o.
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
    # Modify the values to your needs:
    # <version> i. e. 'v2.6'
    # <architecture> i. e. 'x86_64'
    cp -f *.apk /data/ci/results/ci-results-eisfair-ng/<version>/<architecture>
else
    exit $rtc
fi
----->8 nip 8<----------------
- Post-build action 'Build other project'
-- Choose proper repository update job, see next section
-- 'Trigger even if the build is unstable'
- Add some notification Post-build actions if you like

2.3 Update package repository jobs
'_eisfair-ng__updateRepoIndex_x86' and '_eisfair-ng__updateRepoIndex_x86_64'
Here the relevant settings for this job:
- Freestyle job
- Names i. e. '_eisfair-ng__updateRepoIndex_x86' or '_eisfair-ng__updateRepoIndex_x86_64_v2.6'
- Restrict where these jobs can be run
-- v2.6-job on a build node based on alpine linux v2.6 a.s.o.
-- x86-job on a 32bit build node, x86_64-job on a 64bit build node a.s.o.
- VCS: 'None'
- Build trigger 'Build after other projects are built'. Will be filled
  automatically.
- Build: 'Execute shell' with the following content:
./createRepoIndex.sh -v <version> -a <architecture>
- Add some notification Post-build actions if you like



[1] http://jenkins-ci.org
