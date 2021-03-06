#!python

import os, sys, string, time, BaseHTTPServer, getopt, re, subprocess, webbrowser
from operator import itemgetter

from utils import *
from scaffold import Scaffold
from findorfs import parse_genemarkout
from findorfs import parse_fraggenescanout
from findorfs import parse_prokka

sys.path.append(INITIAL_UTILS)
from ruffus import *

_readlibs = []
_skipsteps = []
_settings = Settings()
_orf = ""
def init(reads, skipsteps,orf):
   global _readlibs
   global _skipsteps
   global _orf
   _readlibs = reads
   _skipsteps = skipsteps
   _orf = orf

@follows(Scaffold)
@posttask(touch_file("%s/Logs/findscaffoldorfs.ok"%(_settings.rundir)))
@files("%s/Scaffold/out/%s.linearize.scaffolds.final"%(_settings.rundir,_settings.PREFIX),"%s/FindScaffoldORFS/out/%s.fna"%(_settings.rundir,_settings.PREFIX))
def FindScaffoldORFS(input,output):
   if "FindScaffoldORFS" in _skipsteps:
      run_process(_settings, "touch %s/FindScaffoldORFS/out/%s.scaffolds.faa"%(_settings.rundir, _settings.PREFIX))
      run_process(_settings, "touch %s/Logs/findscaffoldorfs.skip"%(_settings.rundir), "FindScaffoldORFS")
      return 0
   if _orf == "metagenemark":
       if not os.path.exists(_settings.METAGENEMARK + os.sep + "gmhmmp"):
          print "Error: MetaGeneMark not found in %s. Please check your path and try again.\n"%(_settings.METAGENEMARK)
          raise(JobSignalledBreak)
       run_process(_settings, "%s/gmhmmp -o %s/FindScaffoldORFS/out/%s.scaffolds.orfs -m %s/config/MetaGeneMark_v1.mod -d -a %s/Scaffold/out/%s.linearize.scaffolds.final"%(_settings.METAGENEMARK,_settings.rundir,_settings.PREFIX,_settings.METAMOS_UTILS,_settings.rundir,_settings.PREFIX),"FindScaffoldORFS")
       parse_genemarkout("%s/FindScaffoldORFS/out/%s.scaffolds.orfs"%(_settings.rundir,_settings.PREFIX),1, "FindScaffoldORFS")
   elif _orf == "fraggenescan":
       if not os.path.exists(_settings.FRAGGENESCAN + os.sep + "FragGeneScan"):
          print "Error: FragGeneScan not found in %s. Please check your path and try again.\n"%(_settings.FRAGGENESCAN)
          raise(JobSignalledBreak)
       run_process(_settings,"%s/FragGeneScan -s %s/Scaffold/out/%s.linearize.scaffolds.final -o %s/FindScaffoldORFS/out/%s.orfs -w 0 -t complete"%(_settings.FRAGGENESCAN,_settings.rundir,_settings.PREFIX,_settings.rundir,_settings.PREFIX),"FindScaffoldORFS")
       parse_fraggenescanout("%s/FindScaffoldORFS/out/%s.orfs"%(_settings.rundir,_settings.PREFIX), 1, "FindScaffoldORFS")
       run_process(_settings,"cp %s/FindScaffoldORFS/out/%s.orfs.ffn %s/FindScaffoldORFS/out/%s.fna"%(_settings.rundir,_settings.PREFIX,_settings.rundir,_settings.PREFIX),"FindScaffoldORFS")
       run_process(_settings,"cp %s/FindScaffoldORFS/out/%s.orfs.faa %s/FindScaffoldORFS/out/%s.faa"%(_settings.rundir,_settings.PREFIX,_settings.rundir,_settings.PREFIX),"FindScaffoldORFS")
   elif _orf == "prokka":
      if not os.path.exists(_settings.PROKKA + os.sep + "prokka"):
         print "Error: Prokka not found in %s. Please check your paths and try again"%(_settings.PROKKA)
         raise(JobSignalledBreak)

      libUpdate = "%s/lib/"%(os.path.dirname(_settings.PROKKA))
      if "PERL5LIB" in os.environ:
         libUpdate = "%s%s%s"%(os.environ["PERL5LIB"], os.pathsep, libUpdate)
      os.environ["PERL5LIB"]=libUpdate
      print "The path for proka is %s"%(libUpdate)
      prokkaOptions = getProgramParams(_settings.METAMOS_UTILS, "prokka.spec", "", "-")
      if "--gram" in prokkaOptions and not os.path.exists(_settings.SIGNALP + os.sep + "signalp"):
         print "Warning: Prokka option --gram requires SignalP which is not found. Disabling"
         prokkaOptions = prokkaOptions.replace("--gram", "")

      run_process(_settings, "%s/prokka --outdir %s/FindScaffoldORFS/out/prokka --prefix %s --force %s/Scaffold/out/%s.linearize.scaffolds.final"%(_settings.PROKKA, _settings.rundir, _settings.PREFIX, _settings.rundir, _settings.PREFIX), "FindScaffoldORFS")
      parse_prokka("%s/FindScaffoldORFS/out/prokka/%s.gff"%(_settings.rundir,_settings.PREFIX), 1, "FindScaffoldORFS")

      run_process(_settings, "ln %s/FindScaffoldORFS/out/prokka/%s.ffn %s/FindScaffoldORFS/out/%s.fna"%(_settings.rundir, _settings.PREFIX, _settings.rundir, _settings.PREFIX), "FindScaffoldORFS")
      run_process(_settings, "ln %s/FindScaffoldORFS/out/prokka/%s.faa %s/FindScaffoldORFS/out/%s.faa"%(_settings.rundir, _settings.PREFIX, _settings.rundir, _settings.PREFIX), "FindScaffoldORFS")
   else:
       #not recognized
       return 1

   #run_process(_settings, "unlink %s/FindScaffoldORFS/in/%s.scaffolds.faa"%(_settings.rundir,_settings.PREFIX))
   #run_process(_settings, "ln -t %s/Annotate/in/ -s %s/FindScaffoldORFS/out/%s.scaffolds.faa"%(_settings.rundir,_settings.rundir,_settings.PREFIX))
