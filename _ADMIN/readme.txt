How to build eisfair-ng packages using Jenkins
==============================================================================

This document describes how the automated build of eisfair-ng packages can be
performed using the continuous integration tool 'Jenkins' [1].

Steps to do:
------------------------------------------------------------------------------
1. Install Jenkins

1.1 Install the folders plugin
See https://wiki.jenkins-ci.org/display/JENKINS/CloudBees+Folders+Plugin



2. Setup folder structure
Create jobs using job type "Folder" to setup this schema:
- eisfair-ng           This name is fix to separate the e-ng jobs from other
                       jobs on the jenkins installation
 - <alpine-release>    Alpine release for which packages should be build
  - <stage>            Package stage like main or testing
   - <architecture>    Package architecture like x86 or x86_64

This will look like as the following example:
- eisfair-ng
 - v2.7
  - testing
   - x86
   - x86_64
 - v3.1
  - testing
   - x86
   - x86_64



3. Setup the following build jobs for package builds:

3.1 '_eisfair-ng__checkBuildJobs'
This job checks periodically if for every package on the repository the
corresponding build jobs exist. The job determines all template jobs and
creates build jobs for all packages based on them if necessary. See
config.xml on folder _ADMIN/jobTemplates.
Here the relevant settings for this job:
- Freestyle job
- Name: '_eisfair-ng__checkBuildJobs'
- Restrict where this job can be executed to 'master'
- VCS: 'Git' with proper repository URL
- Poll SCM: 'H 2 * * *' which means every day at around 2:??AM. This is
  special Jenkins syntax to spread the load.
- Build environment:
  * Check 'Copy files into the jobs workspace before building'
  * Files to copy: eisfair-ng.buildsettings.txt
  * Paths are relative to: $JENKINS_HOME/userContent
- Build: 'Execute shell' with the following content:

----->8 nip 8<----------------
mv eisfair-ng.buildsettings.txt _ADMIN/settings.txt

# Comma separated list of job folders
jobFolderList='eisfair-ng/v3.1/testing/x86_64'

_ADMIN/checkForNewPackages.sh --job-folder-list $jobFolderList
rtc=$?
if [ $rtc -eq 0 ] ; then
    _ADMIN/createPackageList.sh
fi
----->8 tuck 8<---------------

- Add some notification Post-build actions if you like

3.2 Template jobs for the different build targets
These are the template jobs which will be used to generate new build jobs if
new packages where added to the repository. They are mostly identical with
some minor exceptions. See config.xml on folder _ADMIN/jobTemplates.
Here the relevant settings for these jobs:
- Located on every leaf folder created on step "2. Setup folder structure"
- Freestyle job
- Names i. e. '_TEMPLATE'
- Restrict where this jobs can be executed
-- v2.7-job on a build node based on alpine linux v2.7 a.s.o.
-- x86-job on a 32bit build node, x86_64-job on a 64bit build node a.s.o.
- VCS: 'Git' with proper repository URL
- No build triggers. These jobs will never run directly, they are templates.
- Build: 'Execute shell' with the following content:

----->8 nip 8<----------------
_ADMIN/buildPackage.sh
----->8 tuck 8<---------------

- Post-build action 'Build other project'
-- Choose proper repository update job, see next section
-- 'Trigger even if the build is unstable'
- Add some notification Post-build actions if you like




ToDo: Check/refactor everything beyond this point!
3.3 Update package repository jobs
'_eisfair-ng__updateRepoIndex__v2.7_x86' and '_eisfair-ng__updateRepoIndex__v2.7_x86_64'
See config.xml on folder _ADMIN/jobTemplates. Here the relevant settings for
this job:
- Freestyle job
- Names i. e. '_eisfair-ng__updateRepoIndex__v2.7_x86' or '_eisfair-ng__updateRepoIndex__v2.7_x86_64'
- Restrict where these jobs can be run
-- v2.7-job on a build node based on alpine linux v2.7 a.s.o.
-- x86-job on a 32bit build node, x86_64-job on a 64bit build node a.s.o.
- VCS: 'None'
- Build trigger 'Build after other projects are built'. Will be filled
  automatically.
- Build: 'Execute shell' with the following content:
./createRepoIndex.sh -v <version> -a <architecture>
- Add some notification Post-build actions if you like



4. Setup the following build jobs for package releases:

4.1 '_eisfair-ng__releasePackage'
ToDo: Document this

4.2 Release build jobs for different build targets
'_eisfair-ng__releasePackage__v2.7_x86' and '_eisfair-ng__releasePackage__v2.7_x86_64'
ToDo: Document this



5. Setup the following build jobs to build eisfair-ng iso images:
ToDo: Document this

[1] http://jenkins-ci.org
