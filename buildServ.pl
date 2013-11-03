#!/usr/bin/perl -w
#
# [SpringRTS](http://springrts.com/) lobby bot implementing an automated build
# service for the engine through lobby commands.
# When installing this application on a new server, you need to adapt the
# parameterization constants found in the beginning of this file.
#
# Copyright (C) 2008-2011,2013  Yann Riou <yaribzh@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;

use POSIX ":sys_wait_h";
use IO::Select;
use File::Copy;
use File::Basename;

use SimpleLog;
use BuildServConf;
use SpringLobbyInterface;

use CGI;

$SIG{TERM} = \&sigTermHandler;

my $buildServVer='0.2';

my %buildServHandlers = (
                     defineprofile => \&hDefineProfile,
                     disable => \&hDisable,
                     enable => \&hEnable,
                     help => \&hHelp,
                     helpall => \&hHelpAll,
                     history => \&hHistory,
                     listprofiles => \&hListProfiles,
                     notify => \&hNotify,
                     pending => \&hPending,
                     quit => \&hQuit,
                     rebuild => \&hRebuild,
                     restart => \&hRestart,
                     setuploadrate => \&hSetUploadRate,
                     translate => \&hTranslate,
                     version => \&hVersion
                     );

my %targets = (scons => ["game/spring.exe",
                         "game/unitsync.dll",
                         "game/ArchiveMover.exe",
                         "game/AI/Bot-libs/NTai.dll",
                         "game/AI/Bot-libs/TestGlobalAI.dll",
                         "game/AI/Bot-libs/KAI-0.2.dll",
                         "game/AI/Bot-libs/KAIK-0.13.dll",
                         "game/AI/Bot-libs/JCAI.dll",
                         "game/AI/Bot-libs/AAI.dll",
                         "game/AI/Bot-libs/RAI.dll",
                         "game/AI/Helper-libs/CentralBuildAI.dll",
                         "game/AI/Helper-libs/EconomyAI.dll",
                         "game/AI/Helper-libs/MetalMakerAI.dll",
                         "game/AI/Helper-libs/MexUpgraderAI.dll",
                         "game/AI/Helper-libs/RadarAI.dll",
                         "game/AI/Helper-libs/ReportIdleAI.dll",
                         "game/AI/Helper-libs/SimpleFormationAI.dll",
                         "game/AI/Interfaces/C/0.1/AIInterface.dll",
                         "game/AI/Interfaces/Java/0.1/AIInterface.dll",
                         "game/AI/Skirmish/AAI/0.875/SkirmishAI.dll",
                         "game/AI/Skirmish/AAI/0.9/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/1.34/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/2.11/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/2.13.5/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/3.8.2/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/3.13.1/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/3.18.1/SkirmishAI.dll",
                         "game/AI/Skirmish/KAIK/0.13/SkirmishAI.dll",
                         "game/AI/Skirmish/NTai/XE9.81/SkirmishAI.dll",
                         "game/AI/Skirmish/NullAI/0.1/SkirmishAI.dll",
                         "game/AI/Skirmish/NullLegacyCppAI/0.1/SkirmishAI.dll",
                         "game/AI/Skirmish/RAI/0.601/SkirmishAI.dll"],
               cmake => ["game/spring.exe",
                         "game/spring-dedicated.exe",
                         "game/unitsync.dll",
                         "game/springserver.dll",
                         "game/ArchiveMover.exe",
                         "game/AI/Bot-libs/NTai.dll",
                         "game/AI/Bot-libs/TestGlobalAI.dll",
                         "game/AI/Bot-libs/KAI-0.2.dll",
                         "game/AI/Bot-libs/KAIK-0.13.dll",
                         "game/AI/Bot-libs/JCAI.dll",
                         "game/AI/Bot-libs/AAI.dll",
                         "game/AI/Bot-libs/RAI.dll",
                         "game/AI/Helper-libs/CentralBuildAI.dll",
                         "game/AI/Helper-libs/EconomyAI.dll",
                         "game/AI/Helper-libs/MetalMakerAI.dll",
                         "game/AI/Helper-libs/MexUpgraderAI.dll",
                         "game/AI/Helper-libs/RadarAI.dll",
                         "game/AI/Helper-libs/ReportIdleAI.dll",
                         "game/AI/Helper-libs/SimpleFormationAI.dll",
                         "game/AI/Interfaces/C/0.1/AIInterface.dll",
                         "game/AI/Interfaces/Java/0.1/AIInterface.dll",
                         "game/AI/Skirmish/AAI/0.875/SkirmishAI.dll",
                         "game/AI/Skirmish/AAI/0.9/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/1.34/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/2.11/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/2.13.5/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/3.8.2/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/3.13.1/SkirmishAI.dll",
                         "game/AI/Skirmish/E323AI/3.18.1/SkirmishAI.dll",
                         "game/AI/Skirmish/KAIK/0.13/SkirmishAI.dll",
                         "game/AI/Skirmish/NTai/XE9.81/SkirmishAI.dll",
                         "game/AI/Skirmish/NullAI/0.1/SkirmishAI.dll",
                         "game/AI/Skirmish/NullLegacyCppAI/0.1/SkirmishAI.dll",
                         "game/AI/Skirmish/RAI/0.601/SkirmishAI.dll"]);

my $baseSite='buildbot';
my $baseUrl='http://buildbot.eat-peet.net';
my $srcDir="/home/buildserv/spring/src";
my $installDir="/home/buildserv/spring/install";
my $unixUser='buildserv';
my $bsVarDir='/var/ftp/BuildServ/var';
my $spadsGitDir='/var/ftp/BuildServ';
my %defaults = (vcs => "git",
                toolchain => "mingw32",
                buildsys => "cmake",
                profile => "default",
                rev => "HEAD");
my $defaultRepoName=buildRepositoryName(\%defaults);
my $defaultRepo="$srcDir/$defaultRepoName";
my $masterGitRepo="$srcDir/git.master";
#my $linkColor='12';
#my $errorColor='4';
my $linkColor=' ->';
my $errorColor=' ->';

my %validBuildFlags=(scons => [qw/gml gmlsim debug debugdefines syncdebug synccheck synctrace optimize profile profile_generate profile_use fpmath use_tcmalloc use_mmgr use_gch dc_allowed arch use_nedmalloc/],
                     cmake => [qw/SYNCCHECK DIRECT_CONTROL NO_AVI MARCH_FLAG CMAKE_BUILD_TYPE USE_NEDMALLOC USE_GML USE_GML_SIM USE_GML_DEBUG USE_MMGR TRACE_SYNC SYNCDEBUG AI_EXCLUDE_REGEX AI_TYPES/]);
my $speedLimit=110000;

# Basic checks ################################################################

if($#ARGV < 0 || ! (-f $ARGV[0]) || $#ARGV > 1) {
  print "usage: $0 <configurationFile>\n";
  exit 1;
}

my $confFile=$ARGV[0];
my $sLog=SimpleLog->new(prefix => "[BuildServ] ");
my $buildServ=BuildServConf->new($confFile,$sLog);

sub slog {
  $sLog->log(@_);
}

if(! $buildServ) {
  slog("Unable to load BuildServ configuration at startup",0);
  exit 1;
}

# State variables #############################################################

my %conf=%{$buildServ->{conf}};
my $lSock;
my @sockets=();
my $running=1;
my $quitAfterBuild=0;
my %timestamps=(connectAttempt => 0,
                ping => 0,
                pong => 0,
                repoCheck => 0,
                status => 0);
my %tsBroadcastChan;
if($#ARGV) {
  if($conf{broadcastChannels}) {
    my @broadcastChans=split(/;/,$conf{broadcastChannels});
    foreach my $chan (@broadcastChans) {
      $tsBroadcastChan{$chan}=time;
    }
  }
}
my $lobbyState=0; # (0:not_connected, 1:connecting, 2: connected, 3:logged_in, 4:start_data_received)
my $p_answerFunction;
my %lastSentMessages;
my @messageQueue=();
my @lowPriorityMessageQueue=();
my %lastCmds;
my %ignoredUsers;
my %currentRevision=(rev => "Unknown",
                     author => "Unknown",
                     date => "Unknown");
my %availableRevision=(rev => "Unknown",
                       author => "Unknown",
                       date => "Unknown");
my $buildPid=0;
my $translatePid=0;
my $checkMainRepoPid=0;
my $updatingForRebuild=0;
my $mainRepoCheckedDuringRebuild=0;
my %rebuildParams;
my $rebuildParamsString;
my %buildProfiles;
my $newRevAvailableInTopic=0;
my $rebuildEnabled=0;
my %notifs=(rebuild => {},
            translate => {});


my $lobbySimpleLog=SimpleLog->new(logFiles => [$conf{logDir}."/buildServ.log"],
                                  logLevels => [$conf{lobbyInterfaceLogLevel}],
                                  useANSICodes => [0],
                                  useTimestamps => [1],
                                  prefix => "[SpringLobbyInterface] ");

my $lobby = SpringLobbyInterface->new(serverHost => $conf{lobbyHost},
                                    serverPort => $conf{lobbyPort},
                                    simpleLog => $lobbySimpleLog,
                                    warnForUnhandledMessages => 0);

$SIG{CHLD}="";
$ENV{LANG}="C";
loadProfiles(\%buildProfiles);
loadRevisionInfo(\%currentRevision);
my $tmpString;
fetchMasterGitRepo() if($defaults{vcs} eq "git");
readAvailableRev();
$timestamps{repoCheck}=time;

$SIG{CHLD} = \&sigChldHandler;
my $silentRestart=0;

# Subfunctions ################################################################

sub sigTermHandler {
  quitAfterBuild("SIGTERM signal received");
}

sub sigChldHandler {
  my $childPid;

  while ($childPid = waitpid(-1,WNOHANG)) {
    last if($childPid == -1);
    my $rc=$?;
    if($childPid == $buildPid) {
      $buildPid=0;
      foreach my $notifiedUser (keys %{$notifs{rebuild}}) {
        sayPrivate($notifiedUser,"***** Notification (end of build process) *****");
      }
      $notifs{rebuild}={};
      $updatingForRebuild=0;
      my $repoName = buildRepositoryName(\%rebuildParams);
      if(! $rc && $repoName eq $defaultRepoName && $rebuildParams{upload} eq "yes") {
        if($mainRepoCheckedDuringRebuild) {
#          slog("Skipping readAvailableRevFromRebuild because main repo has been checked during rebuild",3);
        }elsif($rebuildParams{rev} eq "CURRENT") {
#          slog("Skipping readAvailableRevFromRebuild because main repo hasn't been updated for rebuild (rev=CURRENT)",3);
        }else{
#          slog("Reading available rev from rebuild (main repo hasn't been checked during rebuild)",3);
          readAvailableRevFromRebuild();
        }
        my %newRevision=(rev => "Unknown");
        loadRevisionInfo(\%newRevision);
        if($newRevision{rev} ne "Unknown" && $newRevision{rev} ne $currentRevision{rev}) {
          loadRevisionInfo(\%currentRevision);
          setTopic();
          if($conf{broadcastChannels}) {
            my @broadcastChans=split(/;/,$conf{broadcastChannels});
            foreach my $chan (@broadcastChans) {
              printRevInfo($chan) unless($chan eq $conf{masterChannel} || $chan eq "sy");
            }
          }
        }
      }
    }elsif($childPid == $translatePid) {
      $translatePid=0;
      foreach my $notifiedUser (keys %{$notifs{translate}}) {
        sayPrivate($notifiedUser,"***** Notification (end of translate process) *****");
      }
      $notifs{translate}={};
    }elsif($childPid == $checkMainRepoPid) {
      $checkMainRepoPid=0;
      checkMainRepoCallback();
    }
  }

  $SIG{CHLD} = \&sigChldHandler;
}

sub forkedError {
  my ($msg,$level)=@_;
  slog($msg,$level);
  exit 1;
}

sub setStatus {
  return if(time - $timestamps{status} < 2);
  if($lobbyState > 3) {
    my %clientStatus = %{$lobby->{users}->{$conf{lobbyLogin}}->{status}};
    my $inGameTarget=0;
    $inGameTarget=1 if($buildPid || $translatePid || $checkMainRepoPid);
    my $awayTarget=0;
    $awayTarget=1 unless($currentRevision{rev} ne "Unknown" && $availableRevision{rev} ne "Unknown"
                         && (($defaults{vcs} eq "svn" && $currentRevision{rev} < $availableRevision{rev})
                             || ($defaults{vcs} eq "git" && $currentRevision{rev} ne $availableRevision{rev})));
    if($clientStatus{inGame} != $inGameTarget || $clientStatus{away} != $awayTarget) {
      $timestamps{status}=time;
      $clientStatus{inGame}=$inGameTarget;
      $clientStatus{away}=$awayTarget;
      queueLobbyCommand(["MYSTATUS",$lobby->marshallClientStatus(\%clientStatus)]);
    }
  }
}

sub saveRevisionInfo {
  my $p_revInfo=shift;
  my %revInfo=%{$p_revInfo};
  if(%revInfo) {
    if(! open(REVINFO,">$conf{varDir}/currentRevision.txt")) {
      slog("Unable to write current revision informations to $conf{varDir}/currentRevision.txt",1);
      return;
    }
    foreach my $revDataName (keys %revInfo) {
      print REVINFO "$revDataName:$revInfo{$revDataName}\n";
    }
    close(REVINFO);
  }else{
    slog("Unable to write current revision informations: nothing to write !",2);
  }
}

sub loadRevisionInfo {
  my $p_revInfo=shift;
  if(! open(REVINFO,"<$conf{varDir}/currentRevision.txt")) {
    slog("Unable to read current revision informations from $conf{varDir}/currentRevision.txt",1);
    return;
  }
  while(<REVINFO>) {
    if(/^(\w+):(.*)$/) {
      $p_revInfo->{$1}=$2;
    }
  }
  close(REVINFO);
}

sub saveProfiles {
  my $p_profiles=shift;
  my %profiles=%{$p_profiles};
  if(%profiles) {
    if(! open(PROFILES,">$conf{varDir}/buildProfiles.txt")) {
      slog("Unable to write build profiles to $conf{varDir}/buildProfiles.txt",1);
      return;
    }
    foreach my $buildsys (keys %profiles) {
      print PROFILES "[$buildsys]\n";
      foreach my $profile (keys %{$profiles{$buildsys}}) {
        my $flagsString=buildFlagsString($profiles{$buildsys}->{$profile});
        print PROFILES "$profile:$flagsString\n";
      }
    }
    close(PROFILES);
  }else{
    slog("Unable to write build profiles: nothing to write !",2);
  }
}

sub loadProfiles {
  my $p_profiles=shift;
  my $buildsys="";
  if(! open(PROFILES,"<$conf{varDir}/buildProfiles.txt")) {
    slog("Unable to read build profiles from $conf{varDir}/buildProfiles.txt",1);
    return;
  }
  while(<PROFILES>) {
    if(/^\[(\w+)\]/) {
      $buildsys=$1;
      $p_profiles->{$buildsys}={};
      next;
    }
    if(/^(\w+):(.*)$/) {
      my $profile=$1;
      my @flagStrings=split(/ /,$2);
      my %flags;
      foreach my $flagString (@flagStrings) {
        if($flagString =~ /^(\w+)=([\w\.\|\"\*]+)$/) {
          my $flag=$1;
          my $value=$2;
          if(grep(/^$flag$/,@{$validBuildFlags{$buildsys}})) {
            $flags{$flag}=$value;
          }else{
            slog("Invalid flag \"$flag\"",1);
            exit;
          }
        }else{
          slog("Invalid flag string \"$flagString\"",1);
          exit;
        }
      }
      $p_profiles->{$buildsys}->{$profile}=\%flags;
    }
  }
  close(PROFILES);
  foreach $buildsys (keys %{$p_profiles}) {
    slog("Invalid build profiles definition: default profile missing",1) if(! exists $p_profiles->{$buildsys}->{default});
  }
}

sub storeSvnRevisionInfo {
  my ($svnInfoOutput,$p_hash)=@_;
  if($svnInfoOutput =~ /Last Changed Rev\s*:\s*(\d+)\n/) {
    $p_hash->{rev}=$1;
  }
  if($svnInfoOutput =~ /Last Changed Author\s*:\s*(\w+)\n/) {
    $p_hash->{author}=$1;
  }
  if($svnInfoOutput =~ /Last Changed Date\s*:\s*([\d\-\:\+ ]+) \(/) {
    $p_hash->{date}=$1;
  }
}

sub storeGitRevisionInfo {
  my ($gitInfoOutput,$p_hash)=@_;
  my @gitInfo=split("\n",$gitInfoOutput);
  $p_hash->{rev}=$gitInfo[0];
  $p_hash->{author}=$gitInfo[1];
  $p_hash->{date}=$gitInfo[2];
}

sub buildFlagsString {
  my ($p_flags,$buildsys)=@_;
  my $flagPrefix="";
  $flagPrefix="-D" if(defined $buildsys && $buildsys eq "cmake");
  my %flags=%{$p_flags};
  my @flagsStrings;
  foreach my $flag (keys %flags) {
    push(@flagsStrings,"$flagPrefix$flag=$flags{$flag}");
  }
  my $flagsString=join(" ",@flagsStrings);
  return $flagsString;
}

sub fetchMasterGitRepo {
  return unless(-d $masterGitRepo);
  chdir($masterGitRepo);
  system("git fetch --tags");
  system("git fetch");
}

sub readAvailableRev {
  if($defaults{vcs} eq "svn" && -d $defaultRepo) {
    chdir($defaultRepo);
    $tmpString=`svn info -r HEAD`;
    storeSvnRevisionInfo($tmpString,\%availableRevision);
  }elsif($defaults{vcs} eq "git" && -d $masterGitRepo) {
    chdir($masterGitRepo);
    $tmpString=`git describe --tags --long origin/master; git-rev-list --max-count=1 --pretty=format:"%an%n%ci" origin/master | grep -v ^commit`;
    storeGitRevisionInfo($tmpString,\%availableRevision);
  }
}

sub readAvailableRevFromRebuild {
  return unless(-d $defaultRepo);
  chdir($defaultRepo);
  if($defaults{vcs} eq "svn") {
    $tmpString=`svn info`;
    storeSvnRevisionInfo($tmpString,\%availableRevision);
  }elsif($defaults{vcs} eq "git") {
    $tmpString=`git describe --tags --long; git-rev-list --max-count=1 --pretty=format:"%an%n%ci" HEAD | grep -v ^commit`;
    storeGitRevisionInfo($tmpString,\%availableRevision);
  }
}

sub checkMainRepo {
  $timestamps{repoCheck}=time;
  if($updatingForRebuild) {
    slog("checkMainRepo: Cancelling check repository operation (update for rebuild in progress)",2);
    return;
  }
  if($defaults{vcs} eq "git") {
    if($checkMainRepoPid) {
#      slog("checkMainRepo: Cancelling fetch operation (previous call didn't finish yet)",2);
      return;
    }
    return unless(-d $masterGitRepo);
    $checkMainRepoPid = fork();
    return if($checkMainRepoPid);
    fetchMasterGitRepo();
    exit 0;
  }elsif($defaults{vcs} eq "svn") {
    return unless(-d $defaultRepo);
    checkMainRepoCallback();
  }
}

sub checkMainRepoCallback {
  $mainRepoCheckedDuringRebuild=1;
  my $availableRev=$availableRevision{rev};
  readAvailableRev();
  if($availableRevision{rev} ne $availableRev && $availableRevision{rev} ne "Unknown"
     && (($defaults{vcs} eq "svn" && ($currentRevision{rev} eq "Unknown" || $currentRevision{rev} < $availableRevision{rev}))
         || ($defaults{vcs} eq "git" && $currentRevision{rev} ne $availableRevision{rev}))) {
    if($conf{broadcastChannels}) {
      my @broadcastChans=split(/;/,$conf{broadcastChannels});
      foreach my $chan (@broadcastChans) {
        next if($chan eq "sy");
        my $buildChanInfo="in \#$conf{masterChannel} ";
        $buildChanInfo="" if($chan eq $conf{masterChannel});
        sayChan($chan,"New trunk revision available (hit \"!rebuild\" ${buildChanInfo}to build it): $availableRevision{rev} (committed by $availableRevision{author} on $availableRevision{date})") if($rebuildEnabled);
      }
    }
    setTopic() unless($newRevAvailableInTopic);
  }
}

sub printRevInfo {
  my $chan=shift;
  $chan=$conf{masterChannel} unless(defined $chan);
  if($currentRevision{rev} ne "Unknown") {
    $tsBroadcastChan{$chan}=time;
    sayChan($chan,"Latest trunk build uploaded: $currentRevision{rev} (committed by $currentRevision{author} on $currentRevision{date})");
    my $uploadedRev=$currentRevision{rev};
    $uploadedRev="R$uploadedRev" if($uploadedRev =~ /^\d{1,4}$/);
    sayChan($chan,"    Executable: $baseUrl/spring/executable/spring_exe_$uploadedRev.zip");
    sayChan($chan,"    Base files: $baseUrl/spring/base/spring_base_$uploadedRev.tar");
    sayChan($chan,"    Unitsync: $baseUrl/spring/unitsync/unitsync_$uploadedRev.zip");
    sayChan($chan,"    Debug symbols: $baseUrl/spring/debug/spring_dbg_$uploadedRev.7z");
    sayChan($chan,"    Installer: $baseUrl/spring/installer/$currentRevision{installer}");
  }
  if($currentRevision{rev} ne "Unknown" && $availableRevision{rev} ne "Unknown") {
    if(($defaults{vcs} eq "svn" && $currentRevision{rev} < $availableRevision{rev})
       || ($defaults{vcs} eq "git" && $currentRevision{rev} ne $availableRevision{rev})) {
      my $buildChanInfo="in \#$conf{masterChannel} ";
      $buildChanInfo="" if($chan eq $conf{masterChannel});
      sayChan($chan,"New trunk revision available (hit \"!rebuild\" ${buildChanInfo}to build it): $availableRevision{rev} (committed by $availableRevision{author} on $availableRevision{date})");
    }else{
      sayChan($chan,"This is the latest trunk revision available on $defaults{vcs} repository.");
    }
  }
}

sub setTopic {
  my $uploadedRev=$currentRevision{rev};
  $uploadedRev="R$uploadedRev" if($uploadedRev =~ /^\d{1,4}$/);
  my $topic="Hi, welcome to BuildServ (automated build bot). For help, hit \"!help\".\\nLatest trunk build uploaded: $currentRevision{rev} (committed by $currentRevision{author} on $currentRevision{date})\\n    Executable: $baseUrl/spring/executable/spring_exe_$uploadedRev.zip\\n    Base files: $baseUrl/spring/base/spring_base_$uploadedRev.tar\\n    Unitsync: $baseUrl/spring/unitsync/unitsync_$uploadedRev.zip\\n    Debug symbols: $baseUrl/spring/debug/spring_dbg_$uploadedRev.7z\\n    Installer: $baseUrl/spring/installer/$currentRevision{installer}";
  if($currentRevision{rev} ne "Unknown" && $availableRevision{rev} ne "Unknown") {
    if(($defaults{vcs} eq "svn" && $currentRevision{rev} < $availableRevision{rev})
       || ($defaults{vcs} eq "git" && $currentRevision{rev} ne $availableRevision{rev})) {
      $newRevAvailableInTopic=1;
      $topic.="\\nNew trunk revision available (hit \"!rebuild\" to build it)";
    }else{
      $newRevAvailableInTopic=0;
      $topic.="\\nThis is the latest trunk revision available on $defaults{vcs} repository.";
    }
  }
  $tsBroadcastChan{$conf{masterChannel}}=time;
# BuildServ is no longer the default buildbot for SpringRTS
#  sayPrivate("ChanServ","!topic #$conf{masterChannel} $topic");
}

sub uploadErrorFile {
  my ($errFile,$repo)=@_;
  return unless(-f $errFile && -s $errFile);
  sayChan($conf{masterChannel},"Uploading STDERR messages ...");
  anonFile($errFile,"");
  my $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put $errFile -o spring/errors/$errFile;quit"`;
  if($output =~ /(\d\d+ bytes transferred(?: in \d+ seconds? \(\d[^\)]+\))?)/) {
    sayChan($conf{masterChannel},"    [OK] $1");
    sayChan($conf{masterChannel},"        $errorColor $baseUrl/spring/errors/$errFile");
  }else{
    print "output=\"$output\"\n";
    sayChan($conf{masterChannel},"    [ERROR] Unable to check transfer status");
  }
}

sub anonFile {
  my ($file,$repo)=@_;
  my $quotedRepo=quotemeta($repo);
  my $alternateRepo=$quotedRepo;
  $alternateRepo=~s/mingw32/windows/g;
  if(open(IN,"<$file")) {
    if(open(OUT,">$file.tmp")) {
      while(<IN>) {
        s/\/$unixUser//g;
        s/$quotedRepo\///g if($quotedRepo);
        s/$alternateRepo\///g if($alternateRepo);
        print OUT $_;
      }
      close(OUT);
    }
    close(IN);
  }
  if(-f "$file.tmp") {
    move("$file.tmp","$file");
  }
}

sub getCpuSpeed {
  if(-f "/proc/cpuinfo" && -r "/proc/cpuinfo") {
    my @cpuInfo=`cat /proc/cpuinfo 2>/dev/null`;
    my %cpu;
    foreach my $line (@cpuInfo) {
      if($line =~ /^([\w\s]*\w)\s*:\s*(.*)$/) {
        $cpu{$1}=$2;
      }
    }
    if(defined $cpu{"model name"} && $cpu{"model name"} =~ /(\d+)\+/) {
      return $1;
    }
    if(defined $cpu{"cpu MHz"} && $cpu{"cpu MHz"} =~ /^(\d+)(?:\.\d*)?$/) {
      return $1;
    }
    if(defined $cpu{bogomips} && $cpu{bogomips} =~ /^(\d+)(?:\.\d*)?$/) {
      return $1;
    }
    slog("Unable to parse CPU info from /proc/cpuinfo",2);
    return 0;
  }else{
    slog("Unable to retrieve CPU info from /proc/cpuinfo",2);
    return 0;
  }
}

sub getLocalLanIp {
  my @ifConfOut=`/sbin/ifconfig`;
  foreach my $line (@ifConfOut) {
    next unless($line =~ /inet addr:\s*(\d+\.\d+\.\d+\.\d+)\s/);
    my $ip=$1;
    if($ip =~ /^10\./ || $ip =~ /192\.168\./) {
      slog("Following local LAN IP address detected: $ip",4);
      return $ip;
    }
    if($ip =~ /^172\.(\d+)\./) {
      if($1 > 15 && $1 < 32) {
        slog("Following local LAN IP address detected: $ip",4);
        return $ip;
      }
    }
  }
  slog("No local LAN IP address found",4);
  return "*";
}

sub quitAfterBuild {
  my $reason=shift;
  $quitAfterBuild=1;
  my $msg="Bot shutdown scheduled (reason: $reason)";
  broadcastMsg($msg);
  slog($msg,3);
}

sub restartAfterBuild {
  my ($reason,$broadcast)=@_;
  $quitAfterBuild=2;
  my $msg="Bot restart scheduled (reason: $reason)";
  broadcastMsg($msg) if($broadcast);
  slog($msg,3);
}

sub computeMessageSize {
  my $p_msg=shift;
  my $size=0;
  {
    use bytes;
    foreach my $word (@{$p_msg}) {
      $size+=length($word)+1;
    }
  }
  return $size;
}

sub checkLastSentMessages {
  my $sent=0;
  foreach my $timestamp (keys %lastSentMessages) {
    if(time - $timestamp > $conf{sendRecordPeriod}) {
      delete $lastSentMessages{$timestamp};
    }else{
      foreach my $msgSize (@{$lastSentMessages{$timestamp}}) {
        $sent+=$msgSize;
      }
    }
  }
  return $sent;
}

sub queueLobbyCommand {
  my @params=@_;
  if($params[0]->[0] =~ /SAYPRIVATE/) {
    if(@lowPriorityMessageQueue) {
      push(@lowPriorityMessageQueue,\@params);
    }else{
      my $alreadySent=checkLastSentMessages();
      my $toBeSent=computeMessageSize($params[0]);
      if($alreadySent+$toBeSent+5 >= $conf{maxLowPrioBytesSent}) {
        slog("Output flood protection: queueing low priority message(s)",3);
        push(@lowPriorityMessageQueue,\@params);
      }else{
        sendLobbyCommand(\@params,$toBeSent);
      }
    }
  }elsif(@messageQueue) {
    push(@messageQueue,\@params);
  }else{
    my $alreadySent=checkLastSentMessages();
    my $toBeSent=computeMessageSize($params[0]);
    if($alreadySent+$toBeSent+5 >= $conf{maxBytesSent}) {
      slog("Output flood protection: queueing message(s)",2);
      push(@messageQueue,\@params);
    }else{
      sendLobbyCommand(\@params,$toBeSent);
    }
  }
}

sub sendLobbyCommand {
  my ($p_params,$size)=@_;
  $size=computeMessageSize($p_params->[0]) unless(defined $size);
  my $timestamp=time;
  $lastSentMessages{$timestamp}=[] unless(exists $lastSentMessages{$timestamp});
  push(@{$lastSentMessages{$timestamp}},$size);
  $lobby->sendCommand(@{$p_params});
}

sub checkQueuedLobbyCommands {
  return unless($lobbyState > 1 && (@messageQueue || @lowPriorityMessageQueue));
  my $alreadySent=checkLastSentMessages();
  while(@messageQueue) {
    my $toBeSent=computeMessageSize($messageQueue[0]->[0]);
    last if($alreadySent+$toBeSent+5 >= $conf{maxBytesSent});
    my $p_command=shift(@messageQueue);
    sendLobbyCommand($p_command,$toBeSent);
    $alreadySent+=$toBeSent;
  }
  while(@lowPriorityMessageQueue) {
    my $toBeSent=computeMessageSize($lowPriorityMessageQueue[0]->[0]);
    last if($alreadySent+$toBeSent+5 >= $conf{maxLowPrioBytesSent});
    my $p_command=shift(@lowPriorityMessageQueue);
    sendLobbyCommand($p_command,$toBeSent);
    $alreadySent+=$toBeSent;
  }
}

sub answer {
  my $msg=shift;
  &{$p_answerFunction}($msg);
}

sub broadcastMsg {
  my $msg=shift;
  sayChan($conf{masterChannel},$msg) if($lobbyState >= 4 && (exists $lobby->{channels}->{$conf{masterChannel}}));
}

sub splitMsg {
  my ($longMsg,$maxSize)=@_;
  my @messages=($longMsg =~ /.{1,$maxSize}/gs);
  return \@messages;
}

sub sayPrivate {
  my ($user,$msg)=@_;
  my $p_messages=splitMsg($msg,$conf{maxChatMessageLength}-1);
  foreach my $mes (@{$p_messages}) {
    queueLobbyCommand(["SAYPRIVATE",$user,$mes]);
    logMsg("pv_$user","<$conf{lobbyLogin}> $mes") if($conf{logPvChat});
  }
}

sub sayChan {
  my ($chan,$msg)=@_;
  my $p_messages=splitMsg($msg,$conf{maxChatMessageLength}-3);
  foreach my $mes (@{$p_messages}) {
    queueLobbyCommand(["SAYEX",$chan,"* $mes"]);
  }
}

sub getCommandLevels {
  my ($source,$user,$cmd)=@_;

  my $gameState="stopped";

  my $status="outside";
  return $buildServ->getCommandLevels($cmd,$source,$status,$gameState);

}

sub getUserAccessLevel {
  my $user=shift;
  my $p_userData;
  if(! exists $lobby->{users}->{$user}) {
    return 0;
  }else{
    $p_userData=$lobby->{users}->{$user};
  }
  return $buildServ->getUserAccessLevel($user,$p_userData);
}

sub handleRequest {
  my ($source,$user,$command)=@_;

  my $timestamp=time;
  $lastCmds{$user}={} unless(exists $lastCmds{$user});
  $lastCmds{$user}->{$timestamp}=0 unless(exists $lastCmds{$user}->{$timestamp});
  $lastCmds{$user}->{$timestamp}++;
  return if(checkCmdFlood($user));

  my @cmd=split(/ /,$command);
  my $lcCmd=lc($cmd[0]);

  my %answerFunctions = ( pv => sub { sayPrivate($user,$_[0]) },
                          chan => sub { sayChan($conf{masterChannel},$_[0]) });
  $p_answerFunction=$answerFunctions{$source};

  if(exists $buildServ->{commands}->{$lcCmd}) {

    my $p_levels=getCommandLevels($source,$user,$lcCmd);
    my $level=getUserAccessLevel($user);

    if(defined $p_levels->{directLevel} && $p_levels->{directLevel} ne "" && $level >= $p_levels->{directLevel}) {
      executeCommand($source,$user,\@cmd);
    }else{
      answer("$user, you are not allowed to call command \"$cmd[0]\" in $source in current context.");
    }

  }else{
    answer("$user, \"$cmd[0]\" is not a valid command.") unless($source eq "chan");
  }
}

sub executeCommand {
  my ($source,$user,$p_cmd,$checkOnly)=@_;
  $checkOnly=0 unless(defined $checkOnly);

  my %answerFunctions = ( pv => sub { sayPrivate($user,$_[0]) },
                          chan => sub { sayChan($conf{masterChannel},$_[0]) });
  $p_answerFunction=$answerFunctions{$source};

  my @cmd=@{$p_cmd};
  my $command=lc(shift(@cmd));

  if(exists $buildServHandlers{$command}) {
    return &{$buildServHandlers{$command}}($source,$user,\@cmd,$checkOnly);
  }else{
    answer("$user, \"$command\" is not a valid command.");
    return 0;
  }

}

sub invalidSyntax {
  my ($user,$cmd,$reason)=@_;
  $reason="" unless(defined $reason);
  $reason=" (".$reason.")" if($reason);
  answer("Invalid $cmd command usage$reason. $user, please refer to help sent in private message.");
  executeCommand("pv",$user,["help",$cmd]);
}

sub checkCmdFlood {
  my $user=shift;

  return 0 if(getUserAccessLevel($user) >= $conf{floodImmuneLevel});

  if(exists $ignoredUsers{$user}) {
    if(time > $ignoredUsers{$user}) {
      delete $ignoredUsers{$user};
    }else{
      return 1;
    }
  }

  my @autoIgnoreData=split(/;/,$conf{cmdFloodAutoIgnore});

  my $received=0;
  if(exists $lastCmds{$user}) {
    foreach my $timestamp (keys %{$lastCmds{$user}}) {
      if(time - $timestamp > $autoIgnoreData[1]) {
        delete $lastCmds{$user}->{$timestamp};
      }else{
        $received+=$lastCmds{$user}->{$timestamp};
      }
    }
  }

  if($autoIgnoreData[0] && $received >= $autoIgnoreData[0]) {
    broadcastMsg("Ignoring $user for $autoIgnoreData[2] minute(s) (command flood protection)");
    $ignoredUsers{$user}=time+($autoIgnoreData[2] * 60);
    return 1;
  }
  
  return 0;
}

sub logMsg {
  my ($file,$msg)=@_;
  if(! -d $conf{logDir}."/chat") {
    if(! mkdir($conf{logDir}."/chat")) {
      slog("Unable to create directory \"$conf{logDir}/chat\"",1);
      return;
    }
  }
  if(! open(CHAT,">>$conf{logDir}/chat/$file.log")) {
    slog("Unable to log chat message into file \"$conf{logDir}/chat/$file.log\"",1);
    return;
  }
  my $dateTime=localtime();
  print CHAT "[$dateTime] $msg\n";
  close(CHAT);
}

# BuildServ commands handlers #####################################################

sub hDisable {
  my ($source,$user,$p_params,$checkOnly)=@_;
  $rebuildEnabled=0;
  answer("Rebuild commands disabled");
}

sub hEnable {
  my ($source,$user,$p_params,$checkOnly)=@_;
  $rebuildEnabled=1;
  answer("Rebuild commands enabled");
}

sub hHelp {
  my ($source,$user,$p_params,$checkOnly)=@_;
  my ($cmd)=@{$p_params};

  return 0 if($checkOnly);

  if(defined $cmd) {
    my $helpCommand=lc($cmd);
    
    if(exists $buildServ->{help}->{$helpCommand}) {

      my $p_help=$buildServ->{help}->{$helpCommand};

      sayPrivate($user,"********** Help for command $cmd **********");
      sayPrivate($user,"Syntax:");
      sayPrivate($user,"  ".$p_help->[0]);
      sayPrivate($user,"Details / examples:") if($#{$p_help} > 0);
      for my $i (1..$#{$p_help}) {
        sayPrivate($user,"  ".$p_help->[$i]);
      }

    }else{
      sayPrivate($user,"\"$cmd\" is not a valid command.");
    }
  }else{

    my $level=getUserAccessLevel($user);
    my $p_helpForUser=$buildServ->getHelpForLevel($level);

    sayPrivate($user,"********** Available commands for your access level **********");
    foreach my $i (0..$#{$p_helpForUser->{direct}}) {
      sayPrivate($user,$p_helpForUser->{direct}->[$i]);
    }
  }

}

sub hHelpAll {
  my (undef,$user,undef,$checkOnly)=@_;
  return 1 if($checkOnly);

  my $p_help=$buildServ->{help};

  sayPrivate($user,"********** BuildServ commands **********");
  for my $command (sort (keys %{$p_help})) {
    next unless($command);
    sayPrivate($user,$p_help->{$command}->[0]);
  }
}

sub hQuit {
  my ($source,$user,undef,$checkOnly)=@_;
  return 1 if($checkOnly);
  
  my %sourceNames = ( pv => "private",
                      chan => "channel #$conf{masterChannel}",
                      game => "game",
                      battle => "battle lobby" );

  quitAfterBuild("requested by $user in $sourceNames{$source}");
}

sub hDefineProfile {
  my ($source,$user,$p_params,$checkOnly)=@_;
  my @params=@{$p_params};
  if($#params < 2) {
    invalidSyntax($user,"defineprofile");
    return 0;
  }

  my $buildSys=shift(@params);
  if($buildSys !~ /^scons|cmake$/) {
    sayChan($conf{masterChannel},"Invalid build system \"$buildSys\"");
    return;
  }

  my $profile=shift(@params);
  if($profile !~ /^\w+$/) {
    sayChan($conf{masterChannel},"Invalid profile name \"$profile\"");
    return;
  }
  if($profile eq $defaults{profile}) {
    sayChan($conf{masterChannel},"default profile cannot be modified");
    return;
  }

  my %flags;
  foreach my $param (@params) {
    if($param =~ /^(\w+)=([\w\.\|\-\*]+)$/) {
      my $flag=$1;
      my $value=$2;
      $value="\"$value\"";
      if(! grep(/^$flag$/,@{$validBuildFlags{$buildSys}})) {
        sayChan($conf{masterChannel},"Invalid or unmodifiable configure flag \"$flag\" for $buildSys build system");
        return;
      }
      $flags{$flag}=$value;
    }else{
      sayChan($conf{masterChannel},"Invalid defineProfile parameter format \"$param\" (see !help defineProfile)");
      return;
    }
  }
  
  my $action="created";
  if(exists $buildProfiles{$buildSys}->{$profile}) {
    $action="modified";
  }
  $buildProfiles{$buildSys}->{$profile}=\%flags;
  saveProfiles(\%buildProfiles);

  sayChan($conf{masterChannel},"Build profile \"$profile\" $action for $buildSys build system.");
}

sub hListProfiles {
  my ($source,$user,$p_params,$checkOnly)=@_;
  foreach my $buildsys (sort keys %buildProfiles) {
    answer("Available build profile(s) for $buildsys build system:");
    foreach my $profile (sort keys %{$buildProfiles{$buildsys}}) {
      my %configureFlags=%{$buildProfiles{$buildsys}->{default}};
      my %specificFlags=%{$buildProfiles{$buildsys}->{$profile}};
      foreach my $specificFlag (keys %specificFlags) {
        $configureFlags{$specificFlag}=$specificFlags{$specificFlag};
      }
      my $configureString=buildFlagsString(\%configureFlags,$buildsys);
      answer("  $profile: $configureString");
    }
  }
}

sub hSetUploadRate {
  my ($source,$user,$p_params,$checkOnly)=@_;

  if($#{$p_params} != 0 || $p_params->[0] !~ /^\d+$/) {
    invalidSyntax($user,"setuploadrate");
    return;
  }
  
  $speedLimit = $p_params->[0] * 1000;
  answer("Upload rate limit set to $p_params->[0]KB/s");
}

sub getMatchingTailLength {
  my ($s1,$s2)=@_;
  my $l=0;
  while(substr($s1,length($s1) - 1 - $l,1) eq substr($s2,length($s2) - 1 - $l,1) && $l < length($s1) - 1 && $l < length($s2) - 1) {
    $l++;
  }
  return $l;
}

sub chooseBestMatchingBinary {
  my ($stFile,$p_stTargets)=@_;
  my ($length,$nb)=(0,0);
  $stFile=~s/\\/\//g;
  $stFile=~s/\/[^\/]*$//g;
  for my $targetNb (0..$#{$p_stTargets}) {
    my $stTarget=$p_stTargets->[$targetNb];
    $stTarget=~s/\/[^\/]*$//g;
    my $matchingTailLength=getMatchingTailLength($stTarget,$stFile);
    if($matchingTailLength > $length) {
      print "best match so far: $p_stTargets->[$targetNb]\n";
      $nb=$targetNb;
      $length=$matchingTailLength;
    }
  }
  print "selected $p_stTargets->[$nb]\n";
  return $nb;
}

sub pingMelBot {
  my $result=shift;
  if($result =~ /^http/) {
    $result=CGI::escape($result);
    system("wget -T 3 -t 2 'http://meltraxathome.homeip.net/ladder/?ajax=stacktraceTranslated/$result' -O /dev/null 2>&1");
  }else{
    $result=CGI::escape($result);
    system("wget -T 3 -t 2 'http://meltraxathome.homeip.net/ladder/?ajax=stacktraceNotTranslated/$result' -O /dev/null 2>&1");
  }
}

sub hTranslate {
  my ($source,$user,$p_params,$checkOnly)=@_;

  if($translatePid) {
    sayChan($conf{masterChannel},"Stacktrace translation already in progress.");
    pingMelBot("Stacktrace translation already in progress.") if($user eq "MelBot");
    return;
  }

  my %validTranslateParameters=(rev => ['[\w\.\-]+','LAST'],
                                branch => ['[\w\.\-]+'],
                                tag => ['[\w\.\-]+'],
                                file => ['http:\/\/[\w\.\-\=\?\&\/\;\!\(\)%:]+'],
                                profile => ['\w+'],
                                buildsys => ['scons|cmake'],
                                toolchain => ['mingw32|mingw32_421|mingw64|tdm|tdm433|tdm432'],
                                auto => ['yes|no'],
                                vcs => ['git','svn'],
                                links => ['yes','no'],
                                notify => ['yes','no']);

  my %translateParams=();
  my %detectedParams;

  foreach my $translateParam (@{$p_params}) {
    if($translateParam =~ /^(\w+)=([\w\-\.\/\?\=\&:\;\!\(\)%:]+)$/) {
      my $paramName=$1;
      my $paramValue=$2;
      $paramName="toolchain" if($paramName eq "tc");
      $paramName="buildsys" if($paramName eq "bs");
      $paramName="notify" if($paramName eq "not");
      if(exists $validTranslateParameters{$paramName}) {
        my $valueCorrect=0;
        foreach my $checkString (@{$validTranslateParameters{$paramName}}) {
          if($paramValue =~ /^$checkString$/) {
            $valueCorrect=1;
            last;
          }
        }
        if($valueCorrect) {
          $translateParams{$paramName}=$paramValue;
        }else{
          sayChan($conf{masterChannel},"Invalid translate parameter value \"$paramValue\" (see !help translate)");
          pingMelBot("Invalid translate parameter value \"$paramValue\"") if($user eq "MelBot");
          return;
        }
      }else{
        sayChan($conf{masterChannel},"Invalid translate parameter name \"$paramName\" (see !help translate)");
        pingMelBot("Invalid translate parameter name \"$paramName\"") if($user eq "MelBot");
        return;
      }
    }elsif($translateParam ne "") {
      sayChan($conf{masterChannel},"Invalid translate parameter \"$translateParam\" (see !help translate)");
      pingMelBot("Invalid translate parameter \"$translateParam\"") if($user eq "MelBot");
      return;
    }
  }
  if(! exists $translateParams{file}) {
    sayChan($conf{masterChannel},"file parameter is mandatory (see !help translate)");
    pingMelBot("file parameter is mandatory") if($user eq "MelBot");
    return;
  }
  if(exists $translateParams{branch} && exists $translateParams{tag}) {
    sayChan($conf{masterChannel},"branch and tag parameters are mutually exclusive (see !help translate)");
    pingMelBot("branch and tag parameters are mutually exclusive") if($user eq "MelBot");
    return;
  }
  $translateParams{auto}="yes" unless(exists $translateParams{auto});
  $translateParams{links}="yes" unless(exists $translateParams{links});
  if($translateParams{auto} eq "no") {
    $translateParams{rev}="LAST" unless(exists $translateParams{rev});
    $translateParams{profile}="default" unless(exists $translateParams{profile});
    $translateParams{buildsys}=$defaults{buildsys} unless(exists $translateParams{buildsys});
    $translateParams{toolchain}=$defaults{toolchain} unless(exists $translateParams{toolchain});

    if(! exists $translateParams{vcs}) {
      if($translateParams{rev} =~ /^\d{1,4}$/) {
        $translateParams{vcs}="svn";
      }elsif($translateParams{rev} eq "LAST") {
        $translateParams{vcs}=$defaults{vcs};
      }else{
        $translateParams{vcs}="git";
      }
    }
  }

  if(exists $translateParams{vcs} && exists $translateParams{rev}) {
    if($translateParams{vcs} eq "svn" && $translateParams{rev} !~ /^\d+$/ && ! grep {/^$translateParams{rev}$/} qw/LAST CURRENT/) {
      sayChan($conf{masterChannel},"Invalid revision \"$translateParams{rev}\" for SVN version control system.");
      pingMelBot("branch and tag parameters are mutually exclusive") if($user eq "MelBot");
      return;
    }
  }

  my $translateParamsString="";
  foreach my $translateParam (keys %translateParams) {
    $translateParamsString.=" $translateParam=$translateParams{$translateParam}";
  }

  $notifs{translate}->{$user}=1  if(exists $translateParams{notify} && $translateParams{notify} eq 'yes');
  $translatePid = fork();
  return if($translatePid);

  $SIG{CHLD}="";

  sayChan($conf{masterChannel},"----- Start of translation process ($translateParamsString ) -----");

  my $output="";

  sayChan($conf{masterChannel},"Downloading stacktrace...");
  chdir("$bsVarDir/stacktraceTranslator");
  $output = `wget -T 3 -t 2 '$translateParams{file}' -O stacktrace.in 2>&1`;
  if($output =~ /\(([^\)]+)\).*saved/) {
    sayChan($conf{masterChannel},"    [OK] Downloaded at $1");
  }else{
    sayChan($conf{masterChannel},"    [ERROR] Unable to download stacktrace");
    sayChan($conf{masterChannel},"----- End of translation process ($translateParamsString ) -----");
    pingMelBot("Unable to download stacktrace") if($user eq "MelBot");
    exit 1;
  }

  sayChan($conf{masterChannel},"Detecting build parameters...");
  my $versionDetails="";
  if(open(STACKTRACE,"<stacktrace.in")) {
    while(<STACKTRACE>) {
      if(/Spring [^\(]+ \(([^\)]+)\)[\w\(\) ]* has crashed\./) {
        $versionDetails=$1;
        last;
      }elsif(/Hang detection triggered for Spring [^\(]+ \(([^\)]+)\)[\w\(\) ]*\./) {
        $versionDetails=$1;
        last;
      }
    }
    close(STACKTRACE);
    if($versionDetails ne "") {
      if($versionDetails =~ /^((?:\{(?:scons|cmake)\})?)((?:\[\w+\])?)((?:x86_64\-)?)((?:[\w\.\-]+\-|[\w\.\-]+_)?)R(\d+)$/) {
        $detectedParams{buildsys}="scons";
        $detectedParams{buildsys}=$1 unless($1 eq "");
        $detectedParams{profile}="default";
        $detectedParams{profile}=$2 unless($2 eq "");
        $detectedParams{toolchain}="mingw32";
        $detectedParams{toolchain}="mingw64" if($3 ne "");
        $detectedParams{rev}=$5;
        $detectedParams{vcs}="svn";
        if($4 ne "") {
          my $branchOrTagString=$4;
          if($branchOrTagString =~ /^(.*)_$/) {
            $detectedParams{branch}=$1;
          }elsif($branchOrTagString =~ /^(.*)\-$/) {
            $detectedParams{tag}=$1;
          }
        }
        if($detectedParams{buildsys} =~ /^\{(.+)\}$/) {
          $detectedParams{buildsys}=$1;
        }
        if($detectedParams{profile} =~ /^\[(.+)\]$/) {
          $detectedParams{profile}=$1;
        }
      }elsif($versionDetails =~ /^([\w\.\-]+)((?:\{[\w\.\-\@]+\})?)-(s|c|scons|cmake)((?:\{\w+\})?)((?:-\w+)?)$/) {
        my ($vcsData,$vcsSubData,$buildSys,$buildProfile,$toolChain)=($1,$2,$3,$4,$5);
        $vcsSubData=$1 if($vcsSubData =~ /^\{(.+)\}$/);
        $buildProfile=$1 if($buildProfile =~ /^\{(.+)\}$/);
        $toolChain=$1 if($toolChain =~ /^-(.*)$/);
        if($vcsData =~ /^R(\d+)$/) {
          $detectedParams{rev}=$1;
          $detectedParams{vcs}="svn";
        }else{
          $detectedParams{rev}=$vcsData;
          $detectedParams{vcs}="git";
        }
        if($vcsSubData =~ /^([^\@]*)((?:\@.*)?)$/) {
          $detectedParams{branch}=$1 if($1 ne "");
          my $tag=$2;
          if($tag =~ /^\@([\w\.\-]*)$/) {
            $tag=$1;
            if($tag eq "") {
              if($vcsData =~ /^([\w\.\-]+)-0-g[\da-f]+$/) {
                $tag=$1;
              }else{
                sayChan($conf{masterChannel},"    [WARNING] Inconsistency detected in detailed version string \"$versionDetails\" (unable to find tag in \"$vcsData\")");
              }
            }elsif($detectedParams{rev} =~ /^g[\da-f]+$/) {
              $detectedParams{rev}="$tag-0-$detectedParams{rev}";
            }
            $detectedParams{tag}=$tag if($tag ne "");
          }
        }else{
          sayChan($conf{masterChannel},"    [WARNING] Inconsistency detected in detailed version string \"$versionDetails\" (invalid VCS data format \"$vcsSubData\")");
        }
        $buildSys="scons" if($buildSys eq "s");
        $buildSys="cmake" if($buildSys eq "c");
        $detectedParams{buildsys}=$buildSys;
        if($buildProfile eq "") {
          $detectedParams{profile}="default";
        }else{
          $detectedParams{profile}=$buildProfile;
        }
        if($toolChain eq "") {
          $detectedParams{toolchain}="mingw32";
        }else{
          $detectedParams{toolchain}=$toolChain;
        }
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to parse detailed version string \"$versionDetails\" (BuildServ cannot translate stacktraces generated by foreign binaries)");
        sayChan($conf{masterChannel},"----- End of translation process ($translateParamsString ) -----");
        pingMelBot("Unable to parse detailed version string") if($user eq "MelBot");
        exit 1;
#        sayChan($conf{masterChannel},"    [WARNING] Unable to parse detailed version string \"$versionDetails\", autodetection disabled");
        $versionDetails="";
      }
      if($versionDetails ne "") {
        my $autoDetectedFlags=buildFlagsString(\%detectedParams);
        sayChan($conf{masterChannel},"    [OK] $autoDetectedFlags");
        my @inconsistentParams;
        foreach my $detectedParam (keys %detectedParams) {
          if(exists $translateParams{$detectedParam}) {
            push(@inconsistentParams,$detectedParam) if($translateParams{$detectedParam} ne $detectedParams{$detectedParam}
                                                        && ($detectedParam ne "rev" || $translateParams{$detectedParam} ne "LAST"));
          }else{
            $translateParams{$detectedParam}=$detectedParams{$detectedParam};
          }
        }
        for my $specialParam (qw/branch tag/) {
          push(@inconsistentParams,$specialParam) if(exists $translateParams{$specialParam} && ! exists $detectedParams{$specialParam});
        }
        if(@inconsistentParams) {
          my $inconsistentParamsString=join(",",@inconsistentParams);
          sayChan($conf{masterChannel},"    [WARNING] Following translate parameters inconsistent with auto-detected values: $inconsistentParamsString");
        }
      }
    }else{
      sayChan($conf{masterChannel},"    [WARNING] Unable to find detailed version in infolog, autodetection disabled");      
    }
  }else{
    sayChan($conf{masterChannel},"    [ERROR] Unable to open stacktrace file");
    sayChan($conf{masterChannel},"----- End of translation process ($translateParamsString ) -----");
    pingMelBot("Unable to open stacktrace file") if($user eq "MelBot");
    exit 1;
  }

  if(! exists $translateParams{rev}) {
    my $branchOrTagInfo=', this is probably NOT what you want!';
    $branchOrTagInfo=" for $translateParams{branch} branch, this is probably NOT what you want!" if(exists $translateParams{branch});
    $branchOrTagInfo=" for $translateParams{tag} tag" if(exists $translateParams{tag});
    sayChan($conf{masterChannel},"    [WARNING] Using latest debug symbols available$branchOrTagInfo");
    $translateParams{rev}="LAST";
  }
  if(! exists $translateParams{vcs}) {
    if($translateParams{rev} =~ /^\d{1,4}$/) {
      $translateParams{vcs}="svn";
    }elsif($translateParams{rev} eq "LAST") {
      $translateParams{vcs}=$defaults{vcs};
    }else{
      $translateParams{vcs}="git";
    }
  }

  if($translateParams{links} eq "yes" && $translateParams{vcs} ne "git") {
    sayChan($conf{masterChannel},"    [WARNING] Disabling GitHub links (incompatible VCS: $translateParams{vcs})");
    $translateParams{links}="no";
  }

  $translateParams{profile}=$defaults{profile} unless(exists $translateParams{profile});
  $translateParams{toolchain}=$defaults{toolchain} unless(exists $translateParams{toolchain});
  $translateParams{buildsys}=$defaults{buildsys} unless(exists $translateParams{buildsys});

  my $branchTagPrefix="";
  $branchTagPrefix="$translateParams{branch}_" if(exists $translateParams{branch});
  $branchTagPrefix="$translateParams{tag}-" if(exists $translateParams{tag});
  $branchTagPrefix="$translateParams{toolchain}.".$branchTagPrefix if($translateParams{toolchain} ne $defaults{toolchain});
  $branchTagPrefix="[$translateParams{profile}]".$branchTagPrefix if($translateParams{profile} ne $defaults{profile});
  $branchTagPrefix="{$translateParams{buildsys}}".$branchTagPrefix if($translateParams{buildsys} ne $defaults{buildsys});

  my $translateRev=$translateParams{rev};
  $translateRev="R$1" if($translateParams{vcs} eq "svn" && $translateRev =~ /^(\d+)$/);

  my $repoName;
  my $repo;

  my %findRepoParams=%translateParams;
  $findRepoParams{rev}="HEAD";
  $repoName=buildRepositoryName(\%findRepoParams);
  $repo="$srcDir/$repoName";
  if(! exists $translateParams{branch} && ! exists $translateParams{tag}
     && $translateRev ne "LAST" && ! -f "$repo/game/spring_dbg_$translateRev.7z") {
    $repoName=buildRepositoryName(\%translateParams);
    $repo="$srcDir/$repoName";
  }

  sayChan($conf{masterChannel},"Checking debug data availability...");

  if($translateRev eq "LAST") {
    my $latestRev;
    if(opendir(GAME_DIR,"$repo/game")) {
      if($translateParams{vcs} eq "svn") {
        foreach my $dbgFile (readdir(GAME_DIR)) {
          if($dbgFile =~ /^spring_dbg_R(\d+)\.7z$/) {
            my $currentDbgRev=$1;
            $latestRev=$currentDbgRev unless(defined $latestRev);
            $latestRev=$currentDbgRev if($currentDbgRev>$latestRev);
          }
        }
      }else{
        foreach my $dbgFile (readdir(GAME_DIR)) {
          my $latestTs=0;
          if($dbgFile =~ /^spring_dbg_(.+)\.7z$/) {
            my $currentDbgRev=$1;
            $latestRev=$currentDbgRev unless(defined $latestRev);
            my @dbgStat=stat("$repo/game/$dbgFile");
            if($dbgStat[9] > $latestTs) {
              $latestTs=$dbgStat[9];
              $latestRev=$currentDbgRev;
            }
          }
        }
      }
      closedir(GAME_DIR);
    }else{
      sayChan($conf{masterChannel},"    [ERROR] Unable to find debug data appropriate for request");
      sayChan($conf{masterChannel},"----- End of translation process ($translateParamsString ) -----");
      pingMelBot("Unable to find debug data appropriate for request") if($user eq "MelBot");
      exit 1;
    }
    if(! defined $latestRev) {
      sayChan($conf{masterChannel},"    [ERROR] Unable to find latest debug data appropriate for request");
      sayChan($conf{masterChannel},"----- End of translation process ($translateParamsString ) -----");
      pingMelBot("Unable to find latest debug data appropriate for request") if($user eq "MelBot");
      exit 1;
    }
    $translateParams{rev}=$latestRev;
    if(exists $detectedParams{rev} && $detectedParams{rev} ne $translateParams{rev}) {
      sayChan($conf{masterChannel},"    [WARNING] Following translate parameter inconsistent with auto-detected value: rev");
    }
    $translateRev=$translateParams{rev};
    $translateRev="R$1" if($translateParams{vcs} eq "svn" && $translateRev =~ /^(\d+)$/);
  }

  my $revIdent;
  my $fullRevIdent;

  if($translateParams{links} eq "yes") {
    $revIdent=$translateRev;
    $revIdent=$1 if($translateRev =~ /-g([\da-f]+)$/);
    chdir($repo);
    $fullRevIdent=`git-rev-parse $revIdent`;
    chdir("$bsVarDir/stacktraceTranslator");
    chomp($fullRevIdent);
  }

  my $realTranslateParamsString="";
  my $inStacktraceParamsString="";
  foreach my $translateParam (keys %translateParams) {
    if($translateParam eq "file" && $translateParams{links} eq "yes") {
      $inStacktraceParamsString.=" $translateParam=<a href=\"$translateParams{file}\">$translateParams{file}</a>";
    }else{
      $inStacktraceParamsString.=" $translateParam=$translateParams{$translateParam}";
    }
    $realTranslateParamsString.=" $translateParam=$translateParams{$translateParam}";
  }
  $realTranslateParamsString=~s/^ //;

  my %stTargets;
  foreach my $realTarget (@{$targets{$translateParams{buildsys}}}) {
    my ($baseFileName,$baseDir)=fileparse($realTarget,"\.[^\.]*");
    next unless(-f "$repo/${baseDir}${baseFileName}_dbg_$translateRev.7z");
    $stTargets{$baseFileName}=[] unless(exists $stTargets{$baseFileName});
    push(@{$stTargets{$baseFileName}},"$repo/${baseDir}${baseFileName}_dbg_$translateRev.7z");
  }

  if(! %stTargets) {
    sayChan($conf{masterChannel},"    [ERROR] Unable to find debug data appropriate for request");
    sayChan($conf{masterChannel},"----- End of translation process ($realTranslateParamsString ) -----");
    pingMelBot("Unable to find debug data appropriate for request") if($user eq "MelBot");
    exit 1;
  }

  sayChan($conf{masterChannel},"    [OK]");

  sayChan($conf{masterChannel},"Parsing stacktrace...");
  my %usedBinaries;
  my @stacktrace;
  if(open(STACKTRACE,"<stacktrace.in")) {
    while(<STACKTRACE>) {
      next if(/^\s*$/);
      if(/(?:\[\s*\d+\]\s+)?\(\d+\)\s+(.*[^\s])\s+\[([\dxA-Fa-f]+)\]/) {
        my $stFile=$1;
        my $stAddr=$2;
        my $baseStFile=$stFile;
        $baseStFile=~s/\\/\//g;
        $baseStFile=fileparse($baseStFile);
        $baseStFile=~s/\.[^\.]*$//;
        if(exists($stTargets{$baseStFile})) {
          $usedBinaries{$baseStFile}=[0,undef] unless(exists $usedBinaries{$baseStFile});
          $usedBinaries{$baseStFile}->[0]++;
          $usedBinaries{$baseStFile}->[1]=chooseBestMatchingBinary($stFile,$stTargets{$baseStFile});
          push(@stacktrace,"$baseStFile,$stAddr");
        }else{
          push(@stacktrace,"UNTRANSLATED: $stFile [$stAddr]");
        }
      }elsif(%usedBinaries) {
        last;
      }
    }
    close(STACKTRACE);

    if(%usedBinaries) {
      foreach my $usedBinary (keys %usedBinaries) {
        sayChan($conf{masterChannel},"    [OK] $usedBinaries{$usedBinary}->[0] $usedBinary addresses found");
      }
    }else{
      sayChan($conf{masterChannel},"    [ERROR] Unable to find translatable stacktrace in file");
      sayChan($conf{masterChannel},"----- End of translation process ($realTranslateParamsString ) -----");
      pingMelBot("Unable to find translatable stacktrace in file") if($user eq "MelBot");
      exit 1;
    }
  }

  sayChan($conf{masterChannel},"Decompressing appropriate debug symbols...");
  foreach my $usedBinary (keys %usedBinaries) {
    $output = `7zr e -y -o$bsVarDir/stacktraceTranslator $stTargets{$usedBinary}->[$usedBinaries{$usedBinary}->[1]]`;
    if($output !~ /Everything is Ok/) {
      sayChan($conf{masterChannel},"    [ERROR] Unable to check \"7zr\" output");
      sayChan($conf{masterChannel},"----- End of translation process ($realTranslateParamsString ) -----");
      pingMelBot("Unable to check \"7zr\" output") if($user eq "MelBot");
      exit 1;
    }
  }
  sayChan($conf{masterChannel},"    [OK]");

  chdir("$bsVarDir/stacktraceTranslator");
  sayChan($conf{masterChannel},"Translating stacktrace...");
  my %translateCache;
  my $stackTraceExtension="txt";
  $stackTraceExtension="html" if($translateParams{links} eq "yes");
  my $stacktraceOutputFile="${branchTagPrefix}spring_stktrc_${translateRev}_".time.".$stackTraceExtension";
  my $translateCacheHit=0;

  if(open(TRANSLATED,">$stacktraceOutputFile")) {
    print TRANSLATED "<pre>\n" if($translateParams{links} eq "yes");
    my $functionString="";
    for my $index (0..$#stacktrace) {
      if($stacktrace[$index] =~ /^UNTRANSLATED/) {
        print TRANSLATED "$stacktrace[$index]\n";
        next;
      }elsif($stacktrace[$index] =~ /^(.*),([^,]+)$/) {
        my ($stFile,$stAddr)=($1,$2);
        my $translatedString="";
        if(exists $translateCache{$stFile}->{$stAddr}) {
          $translateCacheHit++;
          $translatedString=$translateCache{$stFile}->{$stAddr};
        }else{
          my @translatedLines=`i586-mingw32msvc-addr2line -f -i -e ${stFile}_$translateRev.dbg $stAddr | i586-mingw32msvc-c++filt -n`;
          for my $lineNb (0..$#translatedLines) {
            chomp($translatedLines[$lineNb]);
            if($lineNb % 2 == 0) {
              $functionString="";
              $functionString=" [$translatedLines[$lineNb]]" unless($translatedLines[$lineNb] eq "??");
            }else{
              my $sourceString=$translatedLines[$lineNb];
              $sourceString =~ s/\/home\/ron\/devel\/debian\/mingw32-runtime\/mingw32-runtime-3.13\/build_dir//g;

              my $quotedRepo=quotemeta($repo);
              my $alternateRepo=$quotedRepo;
              $alternateRepo=~s/mingw32/windows/g;
              my $isSpringFile=0;
              if($sourceString =~ /^$quotedRepo\/(.*)$/) {
                $sourceString=$1;
                $isSpringFile=1;
              }elsif($sourceString =~ /^$alternateRepo\/(.*)$/) {
                $sourceString=$1;
                $isSpringFile=1;
              }
              if($isSpringFile) {
                my $linkString="";
                if($translateParams{links} eq "yes" && $sourceString =~ /(.+)\:(\d+)$/) {
                  my ($srcFilePath,$srcLine)=($1,$2);
                  $translatedString.="<a href=\"http://github.com/spring/spring/commits/$revIdent/$srcFilePath\">$srcFilePath</a>";
                  $translatedString.=":<a href=\"http://github.com/spring/spring/blob/$fullRevIdent/$srcFilePath\#L$srcLine\">$srcLine</a>";
                  $translatedString.="$functionString\n";
                }else{
                  $translatedString.="$sourceString$functionString\n";
                }
              }else{
                $translatedString.="$sourceString$functionString\n";
              }
            }
          }
          $translateCache{$stFile}->{$stAddr}=$translatedString;
        }
        print TRANSLATED $translatedString;
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Internal error !");
        sayChan($conf{masterChannel},"----- End of translation process ($realTranslateParamsString ) -----");
        pingMelBot("Internal error") if($user eq "MelBot");
        exit 1;
      }
    }
    print TRANSLATED "--\n$inStacktraceParamsString";
    print TRANSLATED "\n</pre>\n" if($translateParams{links} eq "yes");
    close(TRANSLATED);
    my $cacheHitPercent=int($translateCacheHit * 100 / ($#stacktrace + 1));
    sayChan($conf{masterChannel},"    [OK] Stacktrace stored in file $stacktraceOutputFile (cache hit: $cacheHitPercent%)");
  }else{
    sayChan($conf{masterChannel},"    [ERROR] Unable to write to translated stacktrace file");
    sayChan($conf{masterChannel},"----- End of translation process ($realTranslateParamsString ) -----");
    pingMelBot("Unable to write to translated stacktrace file") if($user eq "MelBot");
    exit 1;
  }
  
  sayChan($conf{masterChannel},"Uploading stacktrace to $baseUrl/spring/stacktrace ...");
  anonFile($stacktraceOutputFile,$repo);
  $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put $stacktraceOutputFile -o spring/stacktrace/$stacktraceOutputFile;quit"`;
  if($output =~ /(\d\d+ bytes transferred(?: in \d+ seconds? \(\d[^\)]+\))?)/) {
    sayChan($conf{masterChannel},"    [OK] $1");
    sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/stacktrace/$stacktraceOutputFile");
  }else{
    sayChan($conf{masterChannel},"    [ERROR] Unable to check transfer status");
    sayChan($conf{masterChannel},"----- End of translation process ($realTranslateParamsString ) -----");
    pingMelBot("Unable to check transfer status") if($user eq "MelBot");
    exit 1;
  }
  
  sayChan($conf{masterChannel},"----- End of translation process ($realTranslateParamsString ) -----");
  pingMelBot("$baseUrl/spring/stacktrace/$stacktraceOutputFile") if($user eq "MelBot");

  exit 0;

}
    
sub exitError {
  my $message=shift;
  sayChan($conf{masterChannel},"    [ERROR] $message");
  sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
  exit 1;
}

sub buildRepositoryName {
  my $p_buildParams=shift;
  my %buildParams=%{$p_buildParams};

  my $repoName=$buildParams{vcs};

  my $vcsSubData="";
  if(exists $buildParams{branch}) {
    my $branch=$buildParams{branch};
    $branch =~ s/\}/_/g;
    $branch =~ s/\@/_/g;
    $vcsSubData=$branch;
  }
  if(exists $buildParams{tag}) {
    my $tag=$buildParams{tag};
    $tag =~ s/\}/_/g;
    $vcsSubData.="\@$tag";
  }elsif($buildParams{rev} ne "HEAD" && $buildParams{rev} ne "CURRENT") {
    $vcsSubData.='@REVERT';
  }
  $repoName.="{$vcsSubData}" if($vcsSubData);

  $repoName.=".$buildParams{toolchain}.$buildParams{buildsys}";
  $repoName.="{$buildParams{profile}}" if($buildParams{profile} ne "default");
  
  return $repoName;
}

sub buildAdditional {
  my $updateRev=shift;

  my $additional=$updateRev;
  my $vcsSubData="";
  if(exists $rebuildParams{branch}) {
    my $branch=$rebuildParams{branch};
    $branch =~ s/\}/_/g;
    $branch =~ s/\@/_/g;
    $vcsSubData=$branch;
  }
  if(exists $rebuildParams{tag}) {
    $vcsSubData.='@';
    my $tag=$rebuildParams{tag};
    $tag =~ s/\}/_/g;
    my $quotedTag=quotemeta($tag);
    $vcsSubData.=$tag unless($additional =~ /^$quotedTag-0-g[\da-f]+$/);
  }
  $additional.="{$vcsSubData}" if($vcsSubData);

  $additional.="-$rebuildParams{buildsys}";
  $additional.="{$rebuildParams{profile}}" if($rebuildParams{profile} ne "default");

  $additional.="-$rebuildParams{toolchain}";
  
  return $additional;
}

sub buildInstallDirName {
  my $repoName=$rebuildParams{vcs};

  my $vcsSubData="";
  if(exists $rebuildParams{branch}) {
    my $branch=$rebuildParams{branch};
    $branch =~ s/\}/_/g;
    $branch =~ s/\@/_/g;
    $vcsSubData=$branch;
  }
  if(exists $rebuildParams{tag}) {
    my $tag=$rebuildParams{tag};
    $tag =~ s/\}/_/g;
    $vcsSubData.="\@$tag";
  }elsif($rebuildParams{rev} ne "HEAD" && $rebuildParams{rev} ne "CURRENT") {
    $vcsSubData.='@REVERT';
  }
  $repoName.="{$vcsSubData}" if($vcsSubData);

  $repoName.=".$rebuildParams{buildsys}";
  $repoName.="{$rebuildParams{profile}}" if($rebuildParams{profile} ne "default");
  
  return "$installDir/$repoName";
}

sub initializeRepositoryIfNeeded {
  my $repoName=shift;
  my $repo="$srcDir/$repoName";

  if(! -d $repo) {
    if($rebuildParams{vcs} eq "svn") {
      exitError("Unable to perform requested build with rev=CURRENT (there is no current local revision for such build yet)") if($rebuildParams{rev} eq "CURRENT");
      mkdir($repo);
      if(exists $rebuildParams{branch}) {
        sayChan($conf{masterChannel},"Initializing new SVN repository for branch $rebuildParams{branch}...");
        system("svn co https://spring.clan-sy.com/svn/spring/branches/$rebuildParams{branch} $repo -r $rebuildParams{rev}");
      }elsif(exists $rebuildParams{tag}) {
        sayChan($conf{masterChannel},"Initializing new SVN repository for tag $rebuildParams{tag}...");
        system("svn co https://spring.clan-sy.com/svn/spring/tags/$rebuildParams{tag} $repo -r $rebuildParams{rev}");
      }else{
        sayChan($conf{masterChannel},"Initializing new SVN repository...");
        system("svn co https://spring.clan-sy.com/svn/spring/trunk $repo -r $rebuildParams{rev}");
      }
      if($? == 0) {
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        system("rm -Rf $repo");
        exitError("Unable to checkout requested revision from remote SVN repository");
      }
    }elsif($rebuildParams{vcs} eq "git") {
      if(! -d $masterGitRepo) {
        exitError("Unable to perform requested build with rev=CURRENT (there is no local GIT repository)") if($rebuildParams{rev} eq "CURRENT");
        sayChan($conf{masterChannel},"Initializing main GIT repository...");
        system("git clone git://github.com/spring/spring.git $masterGitRepo");
        exitError("Unable to clone Spring GIT repository") unless(-d $masterGitRepo);
        sayChan($conf{masterChannel},"    [OK]");
      }
      my $gitBranch="master";
      $gitBranch=$rebuildParams{branch} if(exists $rebuildParams{branch});
      if(! -f "$masterGitRepo/.git/refs/heads/$repoName") {
        chdir($masterGitRepo);
        if(! -f "$masterGitRepo/.git/refs/remotes/origin/$gitBranch") {
          exitError("Unable to perform requested build with rev=CURRENT (there is no $gitBranch branch available locally)") if($rebuildParams{rev} eq "CURRENT");
          sayChan($conf{masterChannel},"Updating main GIT repository, looking for branch $gitBranch ...");
          system("git fetch --tags");
          exitError("Unable to fetch remote GIT repository for tags") if($?);
          system("git fetch");
          exitError("Unable to fetch remote GIT repository") if($?);
          exitError("Unable to find branch $gitBranch on GIT repository") unless(-f "$masterGitRepo/.git/refs/remotes/origin/$gitBranch");
          sayChan($conf{masterChannel},"    [OK]");
        }
        if(exists $rebuildParams{tag} && ! -f "$masterGitRepo/.git/refs/tags/$rebuildParams{tag}") {
          exitError("Unable to perform requested build with rev=CURRENT (there is no $rebuildParams{tag} tag available locally)") if($rebuildParams{rev} eq "CURRENT");
          sayChan($conf{masterChannel},"Updating main GIT repository, looking for tag $rebuildParams{tag} ...");
          system("git fetch --tags");
          exitError("Unable to fetch remote GIT repository for tags") if($?);
          system("git fetch");
          exitError("Unable to fetch remote GIT repository") if($?);
          exitError("Unable to find tag $rebuildParams{tag} on GIT repository") unless(-f "$masterGitRepo/.git/refs/tags/$rebuildParams{tag}");
          sayChan($conf{masterChannel},"    [OK]");
        }
        sayChan($conf{masterChannel},"Creating local branch $repoName based on remote branch $gitBranch...");
        system("git branch --track $repoName origin/$gitBranch");
        exitError("Unable to create local branch") if($? || ! -f "$masterGitRepo/.git/refs/heads/$repoName");
        sayChan($conf{masterChannel},"    [OK]");
      }
      sayChan($conf{masterChannel},"Initializing new GIT working directory for local branch $repoName...");
      if(exists $rebuildParams{branch}) {
        system("sh /usr/share/doc/git-core/contrib/workdir/git-new-workdir $masterGitRepo $repo $repoName");
      }else{
        system("sh /usr/share/doc/git-core/contrib/workdir/git-new-workdir $masterGitRepo $repo");
      }
      system("rm -Rf $repo") if($?);
      exitError("Unable to create new working directory") unless(-d $repo);
      if(exists $rebuildParams{tag} && $rebuildParams{rev} eq "CURRENT") {
        chdir($repo);
        system("git checkout -f $rebuildParams{tag}");
      }
      sayChan($conf{masterChannel},"    [OK]");
    }
    if($rebuildParams{toolchain} eq "mingw32") {
      if(exists $rebuildParams{tag}) {
        system("ln -s $srcDir/mingwlibs_git2 $repo/mingwlibs");
      }else{
        system("ln -s $srcDir/mingwlibs_dwarf2 $repo/mingwlibs");
      }
      system("ln -s /home/lordmatt/external $repo/external");
    }elsif($rebuildParams{toolchain} =~ /^mingw32/ || $rebuildParams{toolchain} =~ /^tdm/) {
      if(exists $rebuildParams{tag}) {
        system("ln -s $srcDir/mingwlibs_git2 $repo/mingwlibs");
      }else{
        system("ln -s $srcDir/mingwlibs $repo/mingwlibs");
      }
      system("ln -s /home/lordmatt/external $repo/external");
    }elsif($rebuildParams{toolchain} eq "mingw64") {
      if(exists $rebuildParams{tag}) {
        system("ln -s $srcDir/mingwlibs_v13_w64 $repo/mingwlibs");
      }else{
        system("ln -s $srcDir/mingwlibs_w64 $repo/mingwlibs");
      }
      system("ln -s /home/lordmatt/external $repo/external");
    }
  }
}

sub updateRepository {
  my $repo=shift;
  chdir($repo);
  my $updateRev="Unknown";

  my $output="";
  my %realRevision=(rev => "Unknown");
  my $realRevString="";
  if($rebuildParams{rev} ne "CURRENT") {
    if($rebuildParams{vcs} eq "svn") {
      sayChan($conf{masterChannel},"Updating SVN repository...");
      system("svn revert rts/Game/GameVersion.cpp >/dev/null") unless($rebuildParams{toolchain} eq "native");
      $output=`svn update -r $rebuildParams{rev} --accept theirs-full`;
      if($output =~ / revision (.*)\.$/) {
        $updateRev=$1;
        $tmpString=`svn info`;
        storeSvnRevisionInfo($tmpString,\%realRevision);
        if($updateRev != $realRevision{rev}) {
          $realRevString=" (effective revision: $realRevision{rev})";
        }
        sayChan($conf{masterChannel},"    [OK] SVN repository updated to revision $updateRev$realRevString");
        $updateRev="R$realRevision{rev}";
      }else{
        exitError("Unable to check \"svn update -r $rebuildParams{rev}\" output");
      }
    }elsif($rebuildParams{vcs} eq "git") {
      sayChan($conf{masterChannel},"Updating GIT repository...");
      system("git reset --hard");
      system("git fetch --tags");
      my $fetchRc=$?;
      my $nbFetchTry=0;
      while($fetchRc != 0 && $nbFetchTry < 3) {
        sayChan($conf{masterChannel},"    [WARNING] Retrying fetch operation...");
        sleep(1);
        system("git fetch --tags");
        $fetchRc=$?;
        $nbFetchTry++;
      }
      exitError("Unable to fetch GIT tags into local repository") if($fetchRc != 0);
      system("git fetch");
      exitError("Unable to fetch GIT Spring repository into local repository") if($? != 0);
#      system("git submodule init");
#      system("git submodule update");
      system("git submodule sync");
      system("git submodule update --init");
      system("git checkout rts/Game/GameVersion.cpp >/dev/null");
      if(exists $rebuildParams{tag}) {
        system("git checkout -f $rebuildParams{tag}");
      }elsif($rebuildParams{rev} eq "HEAD") {
        my $gitBranch="master";
        $gitBranch=$rebuildParams{branch} if(exists $rebuildParams{branch});
        system("git merge origin/$gitBranch");
      }else{
        system("git checkout -f $rebuildParams{rev}");
      }
      exitError("Unable to checkout requested revision from local repository") if($? != 0);
      $tmpString=`git describe --tags --long;git-rev-list --max-count=1 --pretty=format:"%an%n%ci" HEAD| grep -v ^commit`;
      storeGitRevisionInfo($tmpString,\%realRevision);
      $updateRev="$realRevision{rev}";
      sayChan($conf{masterChannel},"    [OK] GIT repository updated to revision $updateRev");
    }
  }else{
    if($rebuildParams{vcs} eq "svn") {
      $tmpString=`svn info`;
      storeSvnRevisionInfo($tmpString,\%realRevision);
      $updateRev="R$realRevision{rev}";
    }elsif($rebuildParams{vcs} eq "git") {
      $tmpString=`git describe --tags --long;git-rev-list --max-count=1 --pretty=format:"%an%n%ci" HEAD| grep -v ^commit`;
      storeGitRevisionInfo($tmpString,\%realRevision);
      $updateRev="$realRevision{rev}";
    }
  }
  return ($updateRev,\%realRevision);
}

sub hRebuild {
  my ($source,$user,$p_params,$checkOnly)=@_;

  if($buildPid) {
    sayChan($conf{masterChannel},"Rebuild process already in progress.");
    return;
  }

  if(! $rebuildEnabled) {
    sayChan($conf{masterChannel},"Rebuild commands are currently disabled.");
    return;
  }

  my %validRebuildParameters=(toolchain => ['mingw32','mingw32_421','mingw64','tdm','tdm433','tdm432','native'],
                              rev => ['\w+','HEAD','CURRENT'],
                              upload => ['yes','no','partial'],
                              branch => ['[\w\.\-]+'],
                              tag => ['[\w\.\-]+'],
                              profile => ['\w+'],
                              source => ['yes','no'],
                              portable => ['yes','no'],
                              buildsys => ['scons','cmake'],
                              vcs => ['git','svn'],
                              clean => ['yes','no'],
                              notify => ['yes','no']);

  %rebuildParams=();
  foreach my $rebuildParam (@{$p_params}) {
    if($rebuildParam =~ /^(\w+)=([\w\-\.]+)$/) {
      my $paramName=$1;
      my $paramValue=$2;
      $paramName="toolchain" if($paramName eq "tc");
      $paramName="buildsys" if($paramName eq "bs");
      $paramName="upload" if($paramName eq "up");
      $paramName="notify" if($paramName eq "not");
      if(exists $validRebuildParameters{$paramName}) {
        my $valueCorrect=0;
        foreach my $checkString (@{$validRebuildParameters{$paramName}}) {
          if($paramValue =~ /^$checkString$/) {
            $valueCorrect=1;
            last;
          }
        }
        if($valueCorrect) {
          $rebuildParams{$paramName}=$paramValue;
        }else{
          sayChan($conf{masterChannel},"Invalid rebuild parameter value \"$paramValue\" (see !help rebuild)");
          return;
        }
      }else{
        sayChan($conf{masterChannel},"Invalid rebuild parameter name \"$paramName\" (see !help rebuild)");
        return;
      }
    }elsif($rebuildParam ne "") {
      sayChan($conf{masterChannel},"Invalid rebuild parameter \"$rebuildParam\" (see !help rebuild)");
      return;
    }
  }
  $rebuildParams{source}="no" unless(exists $rebuildParams{source});
  $rebuildParams{portable}="no" unless(exists $rebuildParams{portable});
  $rebuildParams{profile}=$defaults{profile} unless(exists $rebuildParams{profile});
  $rebuildParams{toolchain}=$defaults{toolchain} unless(exists $rebuildParams{toolchain});
  $rebuildParams{buildsys}=$defaults{buildsys} unless(exists $rebuildParams{buildsys});
  $rebuildParams{rev}="HEAD" unless(exists $rebuildParams{rev});
  if(! exists $rebuildParams{vcs}) {
    if($rebuildParams{rev} =~ /^\d{1,4}$/) {
      $rebuildParams{vcs}="svn";
    }elsif($rebuildParams{rev} eq "HEAD") {
      $rebuildParams{vcs}=$defaults{vcs};
    }else{
      $rebuildParams{vcs}="git";
    }
  }
  $rebuildParams{clean}="no" unless(exists $rebuildParams{clean});
  
  if($rebuildParams{vcs} eq "svn" && $rebuildParams{rev} !~ /^\d+$/ && ! grep {/^$rebuildParams{rev}$/} qw/HEAD CURRENT/) {
    sayChan($conf{masterChannel},"Invalid revision \"$rebuildParams{rev}\" for SVN version control system.");
    return;
  }

  if(! exists $rebuildParams{upload}) {
    if(grep {/^$rebuildParams{toolchain}$/} qw/mingw32 mingw32_421 mingw64 tdm tdm433 tdm432/) {
      $rebuildParams{upload}="yes";
      $rebuildParams{upload}="no"; # BuildServ is no longer the default buildbot for SpringRTS
    }else{
      $rebuildParams{upload}="no";
    }
  }
  if($rebuildParams{upload} ne "no" && (! grep {/^$rebuildParams{toolchain}$/} qw/mingw32 mingw32_421 mingw64 tdm tdm433 tdm432/)) {
    sayChan($conf{masterChannel},"Only windows binaries can be uploaded (see !help rebuild)");
    return;
  }
  if(exists $rebuildParams{branch} && exists $rebuildParams{tag}) {
    sayChan($conf{masterChannel},"branch and tag parameters are mutually exclusive (see !help rebuild)");
    return;
  }
  if(! exists $buildProfiles{$rebuildParams{buildsys}}->{$rebuildParams{profile}}) {
    sayChan($conf{masterChannel},"Unknown build profile \"$rebuildParams{profile}\" for $rebuildParams{buildsys} build system (use !listProfiles to see available build profiles)");
    return;
  }

  $rebuildParamsString="";
  foreach my $rebuildParam (keys %rebuildParams) {
    $rebuildParamsString.=" $rebuildParam=$rebuildParams{$rebuildParam}";
  }

  my $repoName = buildRepositoryName(\%rebuildParams);
  my $repo="$srcDir/$repoName";

  sayChan($conf{masterChannel},"----- Start of rebuild process ($rebuildParamsString ) -----");

  $updatingForRebuild=1;
  $mainRepoCheckedDuringRebuild=0;
  $notifs{rebuild}->{$user}=1 if(exists $rebuildParams{notify} && $rebuildParams{notify} eq 'yes');
  $buildPid = fork();
  return if($buildPid);

  $SIG{CHLD}="";

  initializeRepositoryIfNeeded($repoName);
  my ($updateRev,$p_realRevision)=updateRepository($repo);
  my %realRevision=%{$p_realRevision};

  my $branchTagPrefix="";
  $branchTagPrefix="$rebuildParams{branch}_" if(exists $rebuildParams{branch});
  $branchTagPrefix="$rebuildParams{tag}-".$branchTagPrefix if(exists $rebuildParams{tag});
  $branchTagPrefix="$rebuildParams{toolchain}.".$branchTagPrefix if($rebuildParams{toolchain} ne $defaults{toolchain});
  $branchTagPrefix="[$rebuildParams{profile}]".$branchTagPrefix if($rebuildParams{profile} ne $defaults{profile});
  $branchTagPrefix="{$rebuildParams{buildsys}}".$branchTagPrefix if($rebuildParams{buildsys} ne $defaults{buildsys});

  my %configureFlags=%{$buildProfiles{$rebuildParams{buildsys}}->{default}};
  my %specificFlags=%{$buildProfiles{$rebuildParams{buildsys}}->{$rebuildParams{profile}}};
  foreach my $specificFlag (keys %specificFlags) {
    $configureFlags{$specificFlag}=$specificFlags{$specificFlag};
  }
  my $configureString=buildFlagsString(\%configureFlags,$rebuildParams{buildsys});

  chdir($repo);

  if($rebuildParams{clean} eq "yes") {
    sayChan($conf{masterChannel},"Cleaning...");
    if($rebuildParams{buildsys} eq "scons") {
      system("scons -c");
      if($? == 0) {
        system("rm -Rf ./build");
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        exitError("Unable to clean repository");
      }
    }elsif($rebuildParams{buildsys} eq "cmake") {
      system("make clean");
      if($? == 0) {
        system("rm -Rf ./CMakeFiles");
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        system("rm -Rf ./CMakeFiles");
        exitError("Unable to clean repository");
      }
    }
  }

  my $output;
  if(grep {/^$rebuildParams{toolchain}$/} qw/mingw32 mingw32_421 mingw64 tdm tdm433 tdm432/) {

    if($rebuildParams{buildsys} eq "scons") {
      if($rebuildParams{toolchain} eq "mingw32") {
        $ENV{CC}="i386-mingw32msvc-gcc";
        $ENV{CXX}="i386-mingw32msvc-g++";
        $ENV{MINGDIR}="/home/$unixUser/mingw32/i386-mingw32msvc";
        $ENV{RANLIB}="i386-mingw32msvc-ranlib";
        $ENV{AR}="i386-mingw32msvc-ar";
      }elsif($rebuildParams{toolchain} eq "mingw32_421") {
        $ENV{CC}="i586-mingw32msvc-gcc";
        $ENV{CXX}="i586-mingw32msvc-g++";
        $ENV{MINGDIR}="/usr/i586-mingw32msvc";
        $ENV{RANLIB}="i586-mingw32msvc-ranlib";
        $ENV{AR}="i586-mingw32msvc-ar";
      }elsif($rebuildParams{toolchain} eq "mingw64") {
        $ENV{CC}="x86_64-pc-mingw32-gcc";
        $ENV{CXX}="x86_64-pc-mingw32-g++";
        $ENV{MINGDIR}="/home/$unixUser/mingw64/x86_64-pc-mingw32";
        $ENV{RANLIB}="x86_64-pc-mingw32-ranlib";
        $ENV{AR}="x86_64-pc-mingw32-ar";
      }elsif($rebuildParams{toolchain} eq "tdm433") {
        $ENV{CC}="i386-mingw32msvc-gcc";
        $ENV{CXX}="i386-mingw32msvc-g++";
        $ENV{MINGDIR}="/home/$unixUser/mingwTdm433/i386-mingw32msvc";
        $ENV{RANLIB}="i386-mingw32msvc-ranlib";
        $ENV{AR}="i386-mingw32msvc-ar";
      }elsif($rebuildParams{toolchain} eq "tdm432") {
        $ENV{CC}="i386-mingw32msvc-gcc";
        $ENV{CXX}="i386-mingw32msvc-g++";
        $ENV{MINGDIR}="/home/$unixUser/mingwTdm432/i386-mingw32msvc";
        $ENV{RANLIB}="i386-mingw32msvc-ranlib";
        $ENV{AR}="i386-mingw32msvc-ar";
      }elsif($rebuildParams{toolchain} eq "tdm") {
        $ENV{CC}="i386-mingw32msvc-gcc";
        $ENV{CXX}="i386-mingw32msvc-g++";
        $ENV{MINGDIR}="/home/$unixUser/mingwTdm/i386-mingw32msvc";
        $ENV{RANLIB}="i386-mingw32msvc-ranlib";
        $ENV{AR}="i386-mingw32msvc-ar";
      }
    }
    if($rebuildParams{toolchain} eq "mingw64") {
      $ENV{PATH}="/home/$unixUser/mingw64/bin:$ENV{PATH}";
    }elsif($rebuildParams{toolchain} eq "mingw32") {
      $ENV{PATH}="/home/$unixUser/mingw32/bin:$ENV{PATH}";
    }elsif($rebuildParams{toolchain} eq "tdm433") {
      $ENV{PATH}="/home/$unixUser/mingwTdm433/bin:$ENV{PATH}";
    }elsif($rebuildParams{toolchain} eq "tdm432") {
      $ENV{PATH}="/home/$unixUser/mingwTdm432/bin:$ENV{PATH}";
    }elsif($rebuildParams{toolchain} eq "tdm") {
      $ENV{PATH}="/home/$unixUser/mingwTdm/bin:$ENV{PATH}";
    }

    sayChan($conf{masterChannel},"Configuring...");

    if($rebuildParams{buildsys} eq "scons") {
      $output=`scons configure --config=force platform=windows mingwlibsdir=\"$repo/mingwlibs\" prefix=game datadir=. bindir=. libdir=. $configureString`;
      if($output =~ /Everything seems OK/) {
        sayChan($conf{masterChannel},"    [OK] $configureString");
      }else{
        exitError("Unable to check \"scons configure\" output");
      }
    }elsif($rebuildParams{buildsys} eq "cmake") {
      unlink("$repo/CMakeCache.txt");
#      system("cmake . -DMINGWLIBS=\"$repo/mingwlibs\" -DCMAKE_TOOLCHAIN_FILE=$bsVarDir/spring.$rebuildParams{toolchain}.cmake -DLIBDIR=. -DBINDIR=. -DDATADIR=. -DCMAKE_INSTALL_PREFIX=\"/\" $configureString 1>/dev/null 2>${branchTagPrefix}cmake_$updateRev.txt");
      system("cmake . -DMINGWLIBS=\"$repo/mingwlibs\" -DCMAKE_TOOLCHAIN_FILE=$bsVarDir/spring.$rebuildParams{toolchain}.cmake -DLIBDIR=. -DBINDIR=. -DDATADIR=. -DCMAKE_INSTALL_PREFIX=\"\" $configureString 1>/dev/null 2>${branchTagPrefix}cmake_$updateRev.txt");
      if($? == 0) {
        sayChan($conf{masterChannel},"    [OK] $configureString");
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to check \"cmake .\" output");
        uploadErrorFile("${branchTagPrefix}cmake_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }
    }
    
    sayChan($conf{masterChannel},"Patching rts/Game/GameVersion.cpp file...");
    if($rebuildParams{vcs} eq "svn") {
      system("svn revert rts/Game/GameVersion.cpp >/dev/null");
    }elsif($rebuildParams{vcs} eq "git") {
      system("git checkout rts/Game/GameVersion.cpp >/dev/null");
    }
    my $additional=buildAdditional($updateRev);
    if(open(GAMEVERSION,"<$repo/rts/Game/GameVersion.cpp")) {
      my @gameVersionContent;
      my $newVersionDetails;
      while(<GAMEVERSION>) {
        if(/^(.*\sVERSION_STRING_DETAILED\s*=\s*\")([^\"]*)(\"\s*;.*)$/) {
          push(@gameVersionContent,"$1$2 ($additional)$3\n");
          $newVersionDetails="VERSION_STRING_DETAILED = \"$2 ($additional)\"";
        }elsif(/^(.*\sAdditional\s*=\s*\")([^\"]*)(\"\s*;?.*)$/) {
          push(@gameVersionContent,"$1$additional$3\n");
          $newVersionDetails="Additional = \"$additional\"";
        }else{
          push(@gameVersionContent,$_);
        }
      }
      close(GAMEVERSION);
      if(! defined $newVersionDetails) {
        sayChan($conf{masterChannel},"    [WARNING] VERSION_STRING_DETAILED/Additional not found, patch aborted");
      }else{
        if(open(GAMEVERSION,">$repo/rts/Game/GameVersion.cpp")) {
          foreach my $gameVersionLine (@gameVersionContent) {
            print GAMEVERSION $gameVersionLine;
          }
          close(GAMEVERSION);
          sayChan($conf{masterChannel},"    [OK] $newVersionDetails");
        }else{
          exitError("Unable to write to GameVersion.cpp");
        }
      }
    }else{
      exitError("Unable to read GameVersion.cpp");
    }

    sayChan($conf{masterChannel},"Building...");
    foreach my $target (@{$targets{$rebuildParams{buildsys}}}) {
      unlink("$repo/$target");
    }
    if($rebuildParams{buildsys} eq "scons") {
      $output=`scons -j 2 2>${branchTagPrefix}scons_$updateRev.txt`;
      if($output =~ /scons\: done building targets\.$/) {
        $output=`scons -j 2 unitsync 2>${branchTagPrefix}scons_unitsync_$updateRev.txt`;
        if($output =~ /scons\: done building targets\.$/) {
          system("scons install");
          if($output =~ /scons\: done building targets\.$/) {
            sayChan($conf{masterChannel},"    [OK]");
          }else{
            exitError("Unable to check \"scons install\" output");
          }
        }else{
          sayChan($conf{masterChannel},"    [ERROR] Unable to check \"scons -j 2 unitsync\" output");
          uploadErrorFile("${branchTagPrefix}scons_unitsync_$updateRev.txt",$repo);
          sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
          exit 1;
        }
      }else{
        print "\nSCONS output:\n**********\n$output\n**********\n";
        sayChan($conf{masterChannel},"    [ERROR] Unable to check \"scons -j 2\" output");
        uploadErrorFile("${branchTagPrefix}scons_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }
    }elsif($rebuildParams{buildsys} eq "cmake") {
      system("make -j 2 1>/dev/null 2>${branchTagPrefix}make_$updateRev.txt");
#      system("make -j 2 spring-dedicated 1>/dev/null 2>${branchTagPrefix}make_$updateRev.txt");      
      if($? == 0) {
        system("make install DESTDIR=\"$repo/game\" >${branchTagPrefix}makeInstall_$updateRev.txt 2>&1");
#        system("make install DESTDIR=game 1>/dev/null 2>${branchTagPrefix}makeInstall_$updateRev.txt");
        if($? == 0) {
          sayChan($conf{masterChannel},"    [OK]");
        }else{
          sayChan($conf{masterChannel},"    [ERROR] Unable to check \"make install\" output");
          uploadErrorFile("${branchTagPrefix}makeInstall_$updateRev.txt",$repo);
          sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
          exit 1;
        }
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to check \"make -j 2\" output");
        uploadErrorFile("${branchTagPrefix}make_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }
    }

    sayChan($conf{masterChannel},"Stripping debug symbols...");

    chdir($repo);
    foreach my $target (@{$targets{$rebuildParams{buildsys}}}) {
      my ($baseFileName,$baseDir)=fileparse($target,"\.[^\.]*");
      if(-f "$repo/$target") {
        system("i586-mingw32msvc-strip --only-keep-debug -o ${baseDir}${baseFileName}_$updateRev.dbg $target");
        system("i586-mingw32msvc-strip $target");
      }else{
#        sayChan($conf{masterChannel},"    [WARNING] Unable to find \"$target\" file.");
      }
    }
    sayChan($conf{masterChannel},"    [OK]");

    sayChan($conf{masterChannel},"Compressing spring executable...");
    chdir("$repo/game");
    $output=`zip spring_exe_$updateRev.zip spring.exe`;
    if($output =~ /adding: spring\.exe/ || $output =~ /updating: spring\.exe/) {
      sayChan($conf{masterChannel},"    [OK] ZIP file: ${branchTagPrefix}spring_exe_$updateRev.zip");
    }else{
      exitError("Unable to check \"zip\" output");
    }

    sayChan($conf{masterChannel},"Compressing unitsync library...");
    $output=`zip unitsync_$updateRev.zip unitsync.dll`;
    if($output =~ /adding: unitsync\.dll/ || $output =~ /updating: unitsync\.dll/) {
      sayChan($conf{masterChannel},"    [OK] ZIP file: ${branchTagPrefix}unitsync_$updateRev.zip");
    }else{
      exitError("Unable to check \"zip\" output");
    }

    if($rebuildParams{buildsys} eq "cmake") {
      sayChan($conf{masterChannel},"Compressing dedicated server binaries...");
      system("zip spring_dedicated_$updateRev.zip spring-dedicated.exe springserver.dll >/dev/null");
      if($? == 0) {
        sayChan($conf{masterChannel},"    [OK] ZIP file: ${branchTagPrefix}spring_dedicated_$updateRev.zip");
      }else{
        exitError("Unable to check \"zip\" output");
      }
    }

    if($rebuildParams{upload} ne "no") {
      sayChan($conf{masterChannel},"Uploading spring executable to $baseUrl/spring/executable ...");
      $output=`lftp $baseSite -e "ls spring/executable;quit"`;
      my $quotedExecutable=quotemeta("${branchTagPrefix}spring_exe_$updateRev.zip");
      if($output =~ /\s$quotedExecutable/) {
        sayChan($conf{masterChannel},"    [WARNING] ${branchTagPrefix}spring_exe_$updateRev.zip is already uploaded, skipping upload");
      }else{
        $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put spring_exe_$updateRev.zip -o spring/executable/${branchTagPrefix}spring_exe_$updateRev.zip;quit"`;
        if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
          sayChan($conf{masterChannel},"    [OK] $1");
          sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/executable/${branchTagPrefix}spring_exe_$updateRev.zip");
        }else{
          exitError("Unable to check transfer status");
        }
      }

      sayChan($conf{masterChannel},"Uploading unitsync library to $baseUrl/spring/unitsync ...");
      $output=`lftp $baseSite -e "ls spring/unitsync;quit"`;
      my $quotedUnitsync=quotemeta("${branchTagPrefix}unitsync_$updateRev.zip");
      if($output =~ /\s$quotedUnitsync/) {
        sayChan($conf{masterChannel},"    [WARNING] ${branchTagPrefix}unitsync_$updateRev.zip is already uploaded, skipping upload");
      }else{
        $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put unitsync_$updateRev.zip -o spring/unitsync/${branchTagPrefix}unitsync_$updateRev.zip;quit"`;
        if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
          sayChan($conf{masterChannel},"    [OK] $1");
          sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/unitsync/${branchTagPrefix}unitsync_$updateRev.zip");
        }else{
          exitError("Unable to check transfer status");
        }
      }

      sayChan($conf{masterChannel},"Uploading spring base files to $baseUrl/spring/base ...");
#      unlink("$repo/game/base/spring/bitmaps.sdz");
#      unlink("$repo/game/base/springcontent.sdz");
#      unlink("$repo/game/base/maphelper.sdz");
#      unlink("$repo/game/base/cursors.sdz");
#      chdir("$repo/installer");
#      system("./make_gamedata_arch.sh");
      chdir("$repo/game/base");
      system("tar cvf spring_base_$updateRev.tar spring/bitmaps.sdz springcontent.sdz maphelper.sdz cursors.sdz");
      $output=`lftp $baseSite -e "ls spring/base;quit"`;
      my $quotedBase=quotemeta("${branchTagPrefix}spring_base_$updateRev.tar");
      if($output =~ /\s$quotedBase/) {
        sayChan($conf{masterChannel},"    [WARNING] ${branchTagPrefix}spring_base_$updateRev.tar is already uploaded, skipping upload");
      }else{
        $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put spring_base_$updateRev.tar -o spring/base/${branchTagPrefix}spring_base_$updateRev.tar;quit"`;
        if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
          sayChan($conf{masterChannel},"    [OK] $1");
          sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/base/${branchTagPrefix}spring_base_$updateRev.tar");
        }else{
          exitError("Unable to check transfer status");
        }
      }

      
      if($rebuildParams{buildsys} eq "cmake") {
        chdir("$repo/game");
        sayChan($conf{masterChannel},"Uploading dedicated server binaries to $baseUrl/spring/dedicated ...");
        $output=`lftp $baseSite -e "ls spring/dedicated;quit"`;
        my $quotedDedicated=quotemeta("${branchTagPrefix}spring_dedicated_$updateRev.zip");
        if($output =~ /\s$quotedDedicated/) {
          sayChan($conf{masterChannel},"    [WARNING] ${branchTagPrefix}spring_dedicated_$updateRev.zip is already uploaded, skipping upload");
        }else{
          $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put spring_dedicated_$updateRev.zip -o spring/dedicated/${branchTagPrefix}spring_dedicated_$updateRev.zip;quit"`;
          if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
            sayChan($conf{masterChannel},"    [OK] $1");
            sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/dedicated/${branchTagPrefix}spring_dedicated_$updateRev.zip");
          }else{
            exitError("Unable to check transfer status");
          }
        }
      }

    }

#     chdir("$repo/external");
#     my $tasClientUrl='http://tasclient.it-l.eu/TASClientLatest.7z';
#     if(exists $rebuildParams{tag}) {
#       sayChan($conf{masterChannel},"Downloading latest stable TASClient revision...");
# #      $tasClientUrl='http://tasclient.it-l.eu/TASClientLatestOfficial.7z' ;
#     }else{
#       sayChan($conf{masterChannel},"Downloading latest TASClient revision...");
#     }
#     $output = `wget '$tasClientUrl' -O TASClient.7z 2>&1`;
#     if($output =~ /\(([^\)]+)\).*saved/) {
#       sayChan($conf{masterChannel},"    [OK] Downloaded at $1");
#       sayChan($conf{masterChannel},"Decompressing TASClient...");
#       $output = `7zr e -y TASClient.7z`;
#       if($output =~ /Everything is Ok/) {
#         sayChan($conf{masterChannel},"    [OK]");
#       }else{
#         exitError("Unable to check \"7zr\" output");
#       }
#     }else{
#       sayChan($conf{masterChannel},"    [WARNING] Unable to download TASClient, keeping latest downloaded");
#     }
    
    sayChan($conf{masterChannel},"Compressing debug symbols...");
    foreach my $target (@{$targets{$rebuildParams{buildsys}}}) {
      my ($baseFileName,$baseDir)=fileparse($target,"\.[^\.]*");
      if(-f "$repo/${baseDir}${baseFileName}_$updateRev.dbg") {
        chdir("$repo/$baseDir");
        $output=`7zr a ${baseFileName}_dbg_$updateRev.7z ${baseFileName}_$updateRev.dbg`;
        if($output =~ /Everything is Ok/) {
          unlink("${baseFileName}_$updateRev.dbg");
#          sayChan($conf{masterChannel},"    [OK] ZIP file: ${branchTagPrefix}${baseFileName}_dbg_$updateRev.7z");
        }else{
          exitError("Unable to check \"7zr\" output");
        }
      }else{
#        sayChan($conf{masterChannel},"    [WARNING] Unable to find \"${baseDir}${baseFileName}_$updateRev.dbg\" file.");
      }
    }
    sayChan($conf{masterChannel},"    [OK]");

    if($rebuildParams{upload} eq "yes") {
      chdir("$repo/game");
      sayChan($conf{masterChannel},"Uploading debug symbols to $baseUrl/spring/debug ...");
      $output=`lftp $baseSite -e "ls spring/debug;quit"`;
      my $quotedDebug=quotemeta("${branchTagPrefix}spring_dbg_$updateRev.7z");
      if($output =~ /\s$quotedDebug/) {
        sayChan($conf{masterChannel},"    [WARNING] ${branchTagPrefix}spring_dbg_$updateRev.7z is already uploaded, skipping upload");
      }else{
        $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put spring_dbg_$updateRev.7z -o spring/debug/${branchTagPrefix}spring_dbg_$updateRev.7z;quit"`;
        if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
          sayChan($conf{masterChannel},"    [OK] $1");
          sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/debug/${branchTagPrefix}spring_dbg_$updateRev.7z");
        }else{
          exitError("Unable to check transfer status");
        }
      }
    }

    sayChan($conf{masterChannel},"Building installer...");
    chdir("$repo/installer");
    if(-f "make_installer.pl") {
      $output = `./make_installer.pl 2>&1 | tee ${branchTagPrefix}make_installer_$updateRev.txt`;
    }else{
      my $revisionParamString="";
      $revisionParamString=" $updateRev" if($rebuildParams{vcs} eq "git");
      $output = `./make_test_installer.sh$revisionParamString 2>&1 | tee ${branchTagPrefix}make_installer_$updateRev.txt`;
    }
    my $installerFile="Unknown";
    my $installerBaseFile="Unknown";
    if($output =~ /Output: \"([^\"]+)\"/) {
      $installerFile=$1;
      $installerBaseFile=$installerFile;
      $installerBaseFile=$1 if($installerFile =~ /\/([^\/]+)$/);
      sayChan($conf{masterChannel},"    [OK] Installer file: ${branchTagPrefix}$installerBaseFile");
    }else{
      sayChan($conf{masterChannel},"    [ERROR] Unable to check installer build");
      uploadErrorFile("${branchTagPrefix}make_installer_$updateRev.txt",$repo);
      sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
      exit 1;
    }
    
    if($rebuildParams{upload} eq "yes") {
      sayChan($conf{masterChannel},"Uploading spring installer to $baseUrl/spring/installer ...");
      $output=`lftp $baseSite -e "ls spring/installer;quit"`;
      my $quotedInstaller=quotemeta("${branchTagPrefix}$installerBaseFile");
      if($output =~ /\s$quotedInstaller/ && "${branchTagPrefix}$installerBaseFile" =~ /$realRevision{rev}/) {
        sayChan($conf{masterChannel},"    [WARNING] ${branchTagPrefix}$installerBaseFile is already uploaded, skipping upload");
      }else{
        sayChan($conf{masterChannel},"    [WARNING] Overwriting ${branchTagPrefix}$installerBaseFile") if($output =~ /\s$quotedInstaller/);
        $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put $installerBaseFile -o spring/installer/${branchTagPrefix}$installerBaseFile;quit"`;
        if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
          sayChan($conf{masterChannel},"    [OK] $1");
          sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/installer/${branchTagPrefix}$installerBaseFile");
        }else{
          exitError("Unable to check transfer status");
        }
      }
    }

    if($rebuildParams{source} eq "yes") {
      chdir("$repo/installer");
      sayChan($conf{masterChannel},"Making source packages ...");
      $output = `./make_source_package.sh | tee ${branchTagPrefix}make_sourcePackage_$updateRev.txt`;
      my $tarLzmaFile="Unknown";
      my $tarGzFile="Unknown";
      if($output =~ /Creating \.tar\.lzma archive \(([^\)]+)\)/) {
        $tarLzmaFile=$1;
        if($output =~ /Creating \.tar\.gz archive \(([^\)]+)\)/) {
          $tarGzFile=$1;
          sayChan($conf{masterChannel},"    [OK] Source packages: ${branchTagPrefix}$tarLzmaFile ${branchTagPrefix}$tarGzFile");
        }else{
          sayChan($conf{masterChannel},"    [ERROR] Unable to check source packages");
          uploadErrorFile("${branchTagPrefix}make_sourcePackage_$updateRev.txt",$repo);
          sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
          exit 1;
        }
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to check source packages");
        uploadErrorFile("${branchTagPrefix}make_sourcePackage_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }

      if($rebuildParams{upload} eq "yes") {
        chdir("$repo");
        sayChan($conf{masterChannel},"Uploading source packages to $baseUrl/spring/src ...");
        my $output2=`lftp $baseSite -e "ls spring/src;quit"`;
        my $quotedTarLzma=quotemeta("${branchTagPrefix}$tarLzmaFile");
        sayChan($conf{masterChannel},"    [WARNING] Overwriting ${branchTagPrefix}$tarLzmaFile file") if($output2 =~ /\s$quotedTarLzma/);
        $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put $tarLzmaFile -o spring/src/${branchTagPrefix}$tarLzmaFile;quit"`;
        if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
          sayChan($conf{masterChannel},"    [OK] $1");
          sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/src/${branchTagPrefix}$tarLzmaFile");
        }else{
          exitError("Unable to check transfer status");
        }
        my $quotedTarGz=quotemeta("${branchTagPrefix}$tarGzFile");
        sayChan($conf{masterChannel},"    [WARNING] Overwriting ${branchTagPrefix}$tarGzFile file") if($output2 =~ /\s$quotedTarGz/);
        $output=`lftp $baseSite -e "set net:limit-total-rate $speedLimit;put $tarGzFile -o spring/src/${branchTagPrefix}$tarGzFile;quit"`;
        if($output =~ /(\d\d+ bytes transferred in \d+ seconds? \(\d[^\)]+\))/) {
          sayChan($conf{masterChannel},"    [OK] $1");
          sayChan($conf{masterChannel},"        $linkColor $baseUrl/spring/src/${branchTagPrefix}$tarGzFile");
        }else{
          exitError("Unable to check transfer status");
        }
      }

    }

#    if($rebuildParams{portable} eq "yes") {
#      chdir("$repo/installer");
#      sayChan($conf{masterChannel},"Making portable packages ...");
#      $output = `./make_portable.sh | tee ${branchTagPrefix}make_portable_$updateRev.txt`;

    sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");

    if($repoName eq $defaultRepoName && $rebuildParams{upload} eq "yes") {
      $realRevision{installer}=$installerBaseFile;
      saveRevisionInfo(\%realRevision);
    }

    exit 0;

  }elsif($rebuildParams{toolchain} eq "native") {

    delete $ENV{CC};
    delete $ENV{CXX};
    delete $ENV{MINGDIR};
    delete $ENV{RANLIB};
    delete $ENV{AR};
    $ENV{JAVA_HOME}="/usr/jdk1.6.0_11";

    my $installPath=buildInstallDirName();
    mkdir($installPath) unless(-d $installPath);

    sayChan($conf{masterChannel},"Configuring...");
    if($rebuildParams{buildsys} eq "scons") {
      $output=`scons configure prefix=$installPath installprefix=$installPath`;
      if($output =~ /Everything seems OK/) {
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        exitError("Unable to check \"scons configure\" output");
      }
    }elsif($rebuildParams{buildsys} eq "cmake") {
      unlink("$repo/CMakeCache.txt");
      system("cmake . -DAI_TYPES=NATIVE -DCMAKE_INSTALL_PREFIX=$installPath -DJAVA_INCLUDE_PATH=/usr/jdk1.6.0_11/include 1>/dev/null 2>${branchTagPrefix}cmake_$updateRev.txt");
      if($? == 0) {
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to check \"cmake .\" output");
        uploadErrorFile("${branchTagPrefix}cmake_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }
    }
    
    unlink("$repo/base/spring/bitmaps.sdz");
    unlink("$repo/base/springcontent.sdz");
    unlink("$repo/base/maphelper.sdz");
    unlink("$repo/base/cursors.sdz");
    
    sayChan($conf{masterChannel},"Building...");
    if($rebuildParams{buildsys} eq "scons") {
      $output=`scons -j 2 2>${branchTagPrefix}scons_$updateRev.txt`;
      if($output =~ /scons\: done building targets\.$/) {
        $output=`scons -j 2 unitsync 2>${branchTagPrefix}scons_unitsync_$updateRev.txt`;
        if($output =~ /scons\: done building targets\.$/) {
          sayChan($conf{masterChannel},"    [OK]");
        }else{
          sayChan($conf{masterChannel},"    [ERROR] Unable to check \"scons -j 2 unitsync\" output");
          uploadErrorFile("${branchTagPrefix}scons_unitsync_$updateRev.txt",$repo);
          sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
          exit 1;
        }
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to check \"scons -j 2\" output");
        uploadErrorFile("${branchTagPrefix}scons_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }
    }elsif($rebuildParams{buildsys} eq "cmake") {
      system("make -j 2 1>/dev/null 2>${branchTagPrefix}make_$updateRev.txt");
      if($? == 0) {
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to check \"make -j 2\" output");
        uploadErrorFile("${branchTagPrefix}make_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }
    }
    
    sayChan($conf{masterChannel},"Installing...");
    if($rebuildParams{buildsys} eq "scons") {
      $output=`scons install`;
      if($output =~ /scons\: done building targets\.$/) {
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        exitError("Unable to check \"scons install\" output");
      }
      sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
      exit 0;
    }elsif($rebuildParams{buildsys} eq "cmake") {
      system("make -j 2 install 1>/dev/null 2>${branchTagPrefix}make_install_$updateRev.txt");
      if($? == 0) {
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        sayChan($conf{masterChannel},"    [ERROR] Unable to check \"make -j 2 install\" output");
        uploadErrorFile("${branchTagPrefix}make_install_$updateRev.txt",$repo);
        sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
        exit 1;
      }
    }
    
    if($installPath eq "/home/buildserv/spring/install/git.cmake") {
      unlink("$installPath/share/games/spring/ArchiveCacheV7.lua");
      sayChan($conf{masterChannel},"Updating SpadsGit hosting settings...");
      if(open(CONF,">$spadsGitDir/spadsGit/etc/hostingPresets.conf")) {
        print CONF "[default]\n";
        print CONF "description:Default hosting settings\n";
        print CONF "battleName:[TESTS] Spring $updateRev\n";
        print CONF "modName:~Balanced\\ Annihilation\\ V\\d+\\.\\d+\n";
        print CONF "port:8052\n";
        print CONF "natType:0\n";
        print CONF "password:aaa\n";
        print CONF "maxPlayers:16|2-16\n";
        print CONF "minRank:0\n";
        close(CONF);
      }else{
        exitError("Unable to open configuration file for writing");
      }
      if(open(CONF,">$spadsGitDir/spadsGitTest/etc/hostingPresets.conf")) {
        print CONF "[default]\n";
        print CONF "description:Default hosting settings\n";
        print CONF "battleName:[TESTS] Spring $updateRev\n";
        print CONF "modName:~Balanced\\ Annihilation\\ V\\d+\\.\\d+\n";
        print CONF "port:8952\n";
        print CONF "natType:0\n";
        print CONF "password:aaa\n";
        print CONF "maxPlayers:16|2-16\n";
        print CONF "minRank:0\n";
        close(CONF);
        sayChan($conf{masterChannel},"    [OK]");
      }else{
        exitError("Unable to open configuration file for writing");
      }
     
      sayChan($conf{masterChannel},"Reloading SpadsGit configuration...");
      if(exists $lobby->{users}->{SpadsGit}) {
        sayPrivate("SpadsGit","!reloadConf");
        sayChan($conf{masterChannel},"    [OK] SpadsGit on main server");
      }else{
        sayChan($conf{masterChannel},"    [WARNING] SpadsGit not connected");
      }
      if(exists $lobby->{users}->{TestServerRelay}) {
        sayPrivate("TestServerRelay","!reloadConf");
        sayChan($conf{masterChannel},"    [OK] SpadsGit on test server");
      }else{
        sayChan($conf{masterChannel},"    [WARNING] TestServerRelay not connected");
      }
    }
    
    sayChan($conf{masterChannel},"----- End of rebuild process ($rebuildParamsString ) -----");
    exit 0;

  }else{
    sayChan($conf{masterChannel},"Unknown tool chain \"$rebuildParams{toolchain}\".");
  }
}

sub hHistory {
  my ($source,$user,$p_params,$checkOnly)=@_;

  my %validHistoryParameters=(rev => ['[\w\-\.\/]+'],
                              vcs => ['git','svn']);

  my %historyParams=();
  foreach my $historyParam (@{$p_params}) {
    if($historyParam =~ /^(\w+)=([\w\-\.\/]+)$/) {
      my $paramName=$1;
      my $paramValue=$2;
      if(exists $validHistoryParameters{$paramName}) {
        my $valueCorrect=0;
        foreach my $checkString (@{$validHistoryParameters{$paramName}}) {
          if($paramValue =~ /^$checkString$/) {
            $valueCorrect=1;
            last;
          }
        }
        if($valueCorrect) {
          $historyParams{$paramName}=$paramValue;
        }else{
          answer("Invalid history parameter value \"$paramValue\" (see !help history)");
          return;
        }
      }else{
        answer("Invalid history parameter name \"$paramName\" (see !help history)");
        return;
      }
    }elsif($historyParam ne "") {
      answer("Invalid history parameter \"$historyParam\" (see !help history)");
      return;
    }
  }

  $historyParams{rev}="HEAD" unless(exists $historyParams{rev});

  if(! exists $historyParams{vcs}) {
    if($historyParams{rev} =~ /^\d{1,4}$/) {
      $historyParams{vcs}="svn";
    }elsif($historyParams{rev} eq "HEAD") {
      $historyParams{vcs}=$defaults{vcs};
    }else{
      $historyParams{vcs}="git";
    }
  }

  if($historyParams{vcs} eq "svn" && $historyParams{rev} !~ /^\d+$/ && $historyParams{rev} ne "HEAD") {
    answer("Invalid revision \"$historyParams{rev}\" for SVN version control system.");
    return;
  }

  my %historyDefaults = %defaults;
  $historyDefaults{vcs}=$historyParams{vcs};
  if($historyDefaults{vcs} eq "svn") {
    $historyDefaults{toolchain}="mingw32";
    $historyDefaults{buildsys}="scons";
  }
  my $histoDefaultRepoName=buildRepositoryName(\%historyDefaults);
  my $histoDefaultRepo="$srcDir/$histoDefaultRepoName";
  
  if(! -d $histoDefaultRepo) {
    answer("No data available for \"$historyDefaults{vcs}\" VCS");
    return;
  }

  my $historyPid = fork();
  return if($historyPid);

  chdir($histoDefaultRepo);
  $SIG{CHLD}="";

  my @answers;
  if($historyParams{vcs} eq "git") {
    if($historyParams{rev} ne "HEAD") {
      system("git-rev-parse $historyParams{rev} >/dev/null 2>&1");
      if($? != 0) {
        answer("Invalid revision identifier \"$historyParams{rev}\"");
        exit 1;
      }
    }
    if($historyParams{rev} eq "HEAD") {
      @answers=`git rev-list --date-order --graph -n 10 --pretty=format:"[%an] - %cr%n%s%n" --all`;
    }else{
      @answers=`git rev-list --date-order --graph -n 10 --pretty=format:"[%an] - %cr%n%s%n" $historyParams{rev}`;
    }
    for my $i (0..$#answers) {
      if($answers[$i] =~ /^(.*) commit ([\da-f]+)$/) {
        my $prefix=$1;
        my $commitHash=$2;
        my $revIdent=`git describe --tags --long $commitHash`;
        chomp($revIdent);
        my $urlString="";
#         $urlString=" (http://github.com/spring/spring/commit/$1)" if($revIdent =~ /-g([\da-f]+)$/);
        $urlString=" (http://github.com/spring/spring/commit/$commitHash)";
        $answers[$i]="$prefix $revIdent$urlString";
        $answers[$i].=" < LATEST TRUNK BUILD UPLOADED >" if($revIdent eq $currentRevision{rev});
      }
      chomp($answers[$i]);
    }
  }elsif($historyParams{vcs} eq "svn") {
    if($historyParams{rev} ne "HEAD") {
      system("svn info -r $historyParams{rev} >/dev/null 2>&1");
      if($? != 0) {
        answer("Invalid revision identifier \"$historyParams{rev}\"");
        exit 1;
      }
    }
    my @tmpAnswers;
    if($historyParams{rev} eq "HEAD") {
      @tmpAnswers=`svn log --limit 10`;
    }else{
      @tmpAnswers=`svn log -r $historyParams{rev}:0 --limit 10`;
    }
    for my $i (0..$#tmpAnswers) {
      chomp($tmpAnswers[$i]);
      next if($tmpAnswers[$i] =~ /^$/);
      if($tmpAnswers[$i] =~ /^-*$/) {
        $tmpAnswers[$i]="----";
      }
      push(@answers,$tmpAnswers[$i]);
    }
  }

  sayPrivate($user,"---------- Start of history (rev=$historyParams{rev} vcs=$historyParams{vcs}) ----------");

  for my $i (0..($#answers-1)) {
    sayPrivate($user,$answers[$i]);
  }

  if($historyParams{vcs} eq "git") {
    sayPrivate($user,"---------- Web history available at http://github.com/spring/spring/network ----------");
  }else{
    sayPrivate($user,"---------- End of history (rev=$historyParams{rev} vcs=$historyParams{vcs}) ----------");
  }

  exit 0;
}

sub hNotify {
  my ($source,$user,$p_params,$checkOnly)=@_;
  my $enabled=0;
  $notifs{rebuild}->{$user}=1 if($buildPid);
  $notifs{translate}->{$user}=1 if($translatePid);
  if(exists $notifs{rebuild}->{$user}) {
    if(exists $notifs{translate}->{$user}) {
      answer("Notification enabled: you will be notified when current build and translate processes finish");
    }else{
      answer("Notification enabled: you will be notified when current build process finishes");
    }
  }else{
    if(exists $notifs{translate}->{$user}) {
      answer("Notification enabled: you will be notified when current translate process finishes");
    }else{
      answer("Unable to activate notification: there is no build or translate process running");
    }
  }
}

sub hPending {
  my ($source,$user,$p_params,$checkOnly)=@_;

  if(! -d $defaultRepo) {
    answer("No data available for \"$defaults{vcs}\" VCS");
    return;
  }

  my $pendingPid = fork();
  return if($pendingPid);

  chdir($defaultRepo);
  $SIG{CHLD}="";

  my @answers;
  if($defaults{vcs} eq "git") {
    my $parents=`git rev-list -n 1 --parents $currentRevision{rev}`;
    if($parents =~ /^[\da-f]+ ([\da-f]+(?: [\da-f]+)*)$/) {
      @answers=`git rev-list --date-order --graph -n 20 --pretty=format:"[%an] - %cr%n%s%n" origin/master --not $1`;
    }else{
      @answers=`git rev-list --date-order --graph -n 20 --pretty=format:"[%an] - %cr%n%s%n" origin/master --not $currentRevision{rev}`;
    }
    for my $i (0..$#answers) {
      if($answers[$i] =~ /^(.*) commit ([\da-f]+)$/) {
        my $prefix=$1;
        my $commitHash=$2;
        my $revIdent=`git describe --tags --long $commitHash`;
        chomp($revIdent);
        my $urlString="";
#        $urlString=" (http://github.com/spring/spring/commit/$1)" if($revIdent =~ /-g([\da-f]+)$/);
        $urlString=" (http://github.com/spring/spring/commit/$commitHash)";
        $answers[$i]="$prefix $revIdent$urlString";
        $answers[$i].=" < LATEST TRUNK BUILD UPLOADED >" if($revIdent eq $currentRevision{rev});
      }
      chomp($answers[$i]);
    }
  }elsif($defaults{vcs} eq "svn") {
    my $newRev=$currentRevision{rev}+1;
    system("svn info -r $newRev >/dev/null 2>&1");
    if($? != 0) {
      answer("No commit data for revision >$currentRevision{rev} available");
      exit 1;
    }
    my @tmpAnswers;
    @tmpAnswers=`svn log -r HEAD:$newRev --limit 20`;
    for my $i (0..$#tmpAnswers) {
      chomp($tmpAnswers[$i]);
      next if($tmpAnswers[$i] =~ /^$/);
      if($tmpAnswers[$i] =~ /^-*$/) {
        $tmpAnswers[$i]="----";
      }
      push(@answers,$tmpAnswers[$i]);
    }
  }

  sayPrivate($user,"---------- Start of pending commits ----------");

  for my $i (0..($#answers-1)) {
    sayPrivate($user,$answers[$i]);
  }

  sayPrivate($user,"---------- End of pending commits ----------");

  exit 0;
}

sub hRestart {
  my ($source,$user,$p_params,$checkOnly)=@_;
  return 1 if($checkOnly);
  if($#{$p_params} != -1) {
    $silentRestart=1;
  }
  my %sourceNames = ( pv => "private",
                      chan => "channel #$conf{masterChannel}",
                      game => "game",
                      battle => "battle lobby" );
  my $broadcast=1;
#  $broadcast=0 if($source eq "pv");
  restartAfterBuild("requested by $user in $sourceNames{$source}",$broadcast);
}

sub hVersion {
  my (undef,$user,undef,$checkOnly)=@_;
  
  return 1 if($checkOnly);
  sayPrivate($user,"$conf{lobbyLogin} is running BuildServ v$buildServVer, with following components:");
  my %components = (SpringLobbyInterface => $lobby,
                    BuildServConf => $buildServ,
                    SimpleLog => $sLog);
  foreach my $module (keys %components) {
    my $ver=$components{$module}->getVersion();
    sayPrivate($user,"- $module v$ver");
  }

}

# Lobby interface callbacks ###################################################

sub cbPong {
  $timestamps{pong}=time;
}

sub cbLobbyConnect {
  $lobbyState=2;
  $timestamps{pong}=time;

  $lobby->addCallbacks({CHANNELTOPIC => \&cbChannelTopic,
                        PONG => \&cbPong,
                        LOGININFOEND => \&cbLoginInfoEnd,
                        JOIN => \&cbJoin,
                        JOINFAILED => \&cbJoinFailed,
                        SAID => \&cbSaid,
                        CHANNELMESSAGE => \&cbChannelMessage,
                        SAIDEX => \&cbSaidEx,
                        SAIDPRIVATE => \&cbSaidPrivate,
                        BROADCAST => \&cbBroadcast,
                        JOINED => \&cbJoined,
                        LEFT => \&cbLeft});

  my $localLanIp=$conf{localLanIp};
  $localLanIp=getLocalLanIp() unless($localLanIp);
  queueLobbyCommand(["LOGIN",$conf{lobbyLogin},$lobby->marshallPasswd($conf{lobbyPassword}),getCpuSpeed(),$localLanIp,"BuildServ v$buildServVer"],
                    {ACCEPTED => \&cbLoginAccepted,
                     DENIED => \&cbLoginDenied},
                    \&cbLoginTimeout);
}

sub cbBroadcast {
  my (undef,$msg)=@_;
  print "Lobby broadcast message: $msg\n";
  slog("Lobby broadcast message: $msg",3);
}

sub cbLobbyDisconnect {
  slog("Disconnected from lobby server (connection reset by peer)",2);
  $lobbyState=0;
  foreach my $joinedChan (keys %{$lobby->{channels}}) {
    logMsg("channel_$joinedChan","=== $conf{lobbyLogin} left ===") if($conf{logChanJoinLeave});
  }
  $lobby->disconnect();
}

sub cbConnectTimeout {
  $lobbyState=0;
  slog("Timeout while connecting to lobby server ($conf{lobbyHost}:$conf{lobbyPort})",2);
}

sub cbLoginAccepted {
  $lobbyState=3;
  slog("Logged on lobby server",4);
}

sub cbLoginInfoEnd {
  $lobbyState=4;
  queueLobbyCommand(["JOIN",$conf{masterChannel}]) if($conf{masterChannel});
  if($conf{broadcastChannels}) {
    my @broadcastChans=split(/;/,$conf{broadcastChannels});
    foreach my $chan (@broadcastChans) {
      next if($chan eq $conf{masterChannel});
      queueLobbyCommand(["JOIN",$chan]);
    }
  }
}

sub cbLoginDenied {
  my (undef,$reason)=@_;
  slog("Login denied on lobby server ($reason)",1);
#  quitAfterBuild("login denied on lobby server");
  $lobbyState=0;
  foreach my $joinedChan (keys %{$lobby->{channels}}) {
    logMsg("channel_$joinedChan","=== $conf{lobbyLogin} left ===") if($conf{logChanJoinLeave});
  }
  $lobby->disconnect();
}

sub cbLoginTimeout {
  slog("Unable to log on lobby server (timeout)",2);
  $lobbyState=0;
  foreach my $joinedChan (keys %{$lobby->{channels}}) {
    logMsg("channel_$joinedChan","=== $conf{lobbyLogin} left ===") if($conf{logChanJoinLeave});
  }
  $lobby->disconnect();
}

sub cbJoin {
  my (undef,$channel)=@_;
  slog("Channel $channel joined",4);
  logMsg("channel_$channel","=== $conf{lobbyLogin} joined ===") if($conf{logChanJoinLeave});
  if($channel eq $conf{masterChannel}) {
    setTopic() unless(exists $tsBroadcastChan{$channel} && time - $tsBroadcastChan{$channel} < 21600);
  }elsif($channel ne "sy" && $rebuildEnabled) {
    printRevInfo($channel) unless(exists $tsBroadcastChan{$channel} && time - $tsBroadcastChan{$channel} < 21600);
  }
}

sub cbJoinFailed {
  my (undef,$channel,$reason)=@_;
  slog("Unable to join channel $channel ($reason)",2);
}

sub cbJoined {
  my (undef,$chan,$user)=@_;
  logMsg("channel_$chan","=== $user joined ===") if($conf{logChanJoinLeave});
}

sub cbLeft {
  my (undef,$chan,$user,$reason)=@_;
  my $reasonString ="";
  $reasonString=" ($reason)" if(defined $reason && $reason ne "");
  logMsg("channel_$chan","=== $user left$reasonString ===") if($conf{logChanJoinLeave});
  checkMainRepo() if($defaults{vcs} eq "svn" && $user eq "CommitBot");
}

sub cbSaid {
  my (undef,$chan,$user,$msg)=@_;
  logMsg("channel_$chan","<$user> $msg") if($conf{logChanChat});
  if($chan eq $conf{masterChannel} && $msg =~ /^!(\w.*)$/) {
    handleRequest("chan",$user,$1);
  }
  if($chan eq "sy" && ($user eq "MelBot" || $user eq "TIZBOT") && $msg =~ /\<GitHub.*spring.*master/) {
#    slog("checkMainRepo sur detection GitHub",3);
    checkMainRepo();
  }
}

sub cbChannelMessage {
  my (undef,$chan,$msg)=@_;
  logMsg("channel_$chan","* Channel message: $msg") if($conf{logChanChat});
}

sub cbSaidEx {
  my (undef,$chan,$user,$msg)=@_;
  logMsg("channel_$chan","* $user $msg") if($conf{logChanChat});
  $updatingForRebuild=0 if($user eq $conf{lobbyLogin} && $msg =~ /Configuring\.\.\./);
  checkMainRepo() if($defaults{vcs} eq "git" && $user eq "GitCommitBot" && $msg =~ / committed /);
}

sub cbSaidPrivate {
  my (undef,$user,$msg)=@_;
  logMsg("pv_$user","<$user> $msg") if($conf{logPvChat});
  if($msg =~ /^!(\w.*)$/) {
    handleRequest("pv",$user,$1);
  }
}

sub cbChannelTopic {
  my (undef,$chan,$user,$time,$topic)=@_;
  logMsg("channel_$chan","* Topic is '$topic' (set by $user)") if($conf{logChanChat});
}

# Main ########################################################################

$sLog=$buildServ->{log};

slog("Initializing BuildServ",3);

while($running) {

  if(! $lobbyState && ! $quitAfterBuild) {
    if($timestamps{connectAttempt} != 0 && $conf{lobbyReconnectDelay} == 0) {
      quitAfterBuild("disconnected from lobby server, no reconnection delay configured");
    }else{
      if(time-$timestamps{connectAttempt} > $conf{lobbyReconnectDelay}) {
        $timestamps{connectAttempt}=time;
        $lobbyState=1;
        if(defined $lSock) {
          my @newSockets=();
          foreach my $sock (@sockets) {
            push(@newSockets,$sock) unless($sock == $lSock);
          }
          @sockets=@newSockets;
        }
        $lSock = $lobby->connect(\&cbLobbyDisconnect,{TASSERVER => \&cbLobbyConnect},\&cbConnectTimeout);
        $timestamps{ping}=time;
        $timestamps{pong}=time;
        if($lSock) {
          push(@sockets,$lSock);
        }else{
          $lobbyState=0;
          slog("Connection to lobby server failed",1);
        }
      }
    }
  }

  checkQueuedLobbyCommands();

  my @pendingSockets=IO::Select->new(@sockets)->can_read(1);

  foreach my $pendingSock (@pendingSockets) {
    if($pendingSock == $lSock) {
      $lobby->receiveCommand();
    }
  }

  if($lobbyState > 0 && (time - $timestamps{pong}) > 30) {
    slog("Disconnected from lobby server (ping timeout)",2);
    $lobbyState=0;
    foreach my $joinedChan (keys %{$lobby->{channels}}) {
      logMsg("channel_$joinedChan","=== $conf{lobbyLogin} left ===") if($conf{logChanJoinLeave});
    }
    $lobby->disconnect();
  }

  if($lobbyState > 1 && (time - $timestamps{ping}) > 13) {
    sendLobbyCommand([["PING"]],5);
    $timestamps{ping}=time;
    checkMainRepo() if(time - $timestamps{repoCheck} > 300);
  }

  if($quitAfterBuild) {
    slog("Game is not running, exiting",3);
    $running=0;
  }

  setStatus();
}

if($lobbyState) {
  foreach my $joinedChan (keys %{$lobby->{channels}}) {
    logMsg("channel_$joinedChan","=== $conf{lobbyLogin} left ===") if($conf{logChanJoinLeave});
  }
  $lobby->disconnect();
}
if($quitAfterBuild == 2) {
  $SIG{CHLD}="";
  chdir($ENV{PWD});
  my $silentFlag="";
  $silentFlag=" silent" if($silentRestart);
  exec("$0 $confFile$silentFlag") || forkedError("Unable to restart BuildServ",0);
}

exit 0;
