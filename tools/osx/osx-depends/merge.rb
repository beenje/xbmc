#!/usr/bin/env ruby -w

# Copyright (c) 2007 Elias Pipping
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

libs = %w{ fileutils find logger optparse ostruct pathname set tempfile zlib }

libs.each {|lib| require lib}

module Helpers
  def true_for_all?( filePath, includeFirst )
  # Checks if a predicate is true for all (but the first) architecture
    iterand = includeFirst ? @args : @args[1..-1]
    iterand.all? {|arch| yield( @options.input + arch + filePath, arch )}
  end
end

# These Ruby 1.9 extensions come in handy. In case we are Running ruby 1.8 we
# just define them ourselves
class String
  unless self.method_defined?( :start_with? )
    def start_with?( string )
      self.slice( 0...string.length ) == string
    end
  end
  unless self.method_defined?( :end_with? )
    def end_with?( string )
      self.slice( -string.length..-1 ) == string
    end
  end
end

class Merge

  private

  include Helpers

  class MergeArguments
    def self.parse( arguments )

      # Set up defaults
      options = OpenStruct.new
      options.dryrun  = false

      options.level   = Logger::INFO
      options.log     = 'STDOUT'

      options.exclude = %w{ .svn CVS }

      options.input   = Pathname.pwd
      options.output  = Pathname.pwd + 'out'

      opts = OptionParser.new {|opts|
        opts.banner = 'Usage: %s [options] arch arch [arch [arch ...]]' % $0

        opts.on( '-i', '--input DIRECTORY',
          'Change input directory', %q{Defaults to '.'} ) {|i|
          options.input = Pathname.new( i ).expand_path || options.input
        }

        opts.on( '-o', '--output DIRECTORY',
          'Change output directory', %q{Defaults to './out'} ) {|o|
          options.output = Pathname.new( o ).expand_path || options.output
        }

        opts.on( '-v', '--verbosity LEVEL', 'Change level of verbosity',
           %q{Valid arguments are 'debug', 'info',},
           %q{'warn', 'error', and 'fatal'.}, %q{Defaults to 'info'} ) {|v|
          case v
          when 'debug', 'info', 'warn', 'error', 'fatal'
            options.level = Logger.const_get( v.upcase )
          end
        }

        opts.on( '-l', '--log TARGET', 'Change target to log to',
          %q{Valid arguments are 'STDOUT', 'STDERR',},
          %q{and '/path/to/file'.}, %q{Defaults to 'STDOUT'} ) {|l|
          options.log = l
        }

        opts.on( '-e', '--exclude PATTERN1,PATTERN2', Array,
          'Exclude files/directories (glob-style)') {|e|
          options.exclude = e
        }

        opts.on( '-d', '--[no-]dry-run', 'Perform a dry run' ) {|d|
          options.dryrun = d
        }

        opts.on_tail( '-h', '--help', 'Show this message' ) {
          puts opts
          exit
        }
      }
      opts.parse!( arguments )
      options
    end
  end

  class FileHandler

    include Helpers

    private

    def initialize( options, log, args )
      @options, @log, @args = options, log, args
    end

    def create_directory( prefix, dir )
    # Creates a directory
      prefixed = prefix + dir
      unless prefixed.exist?
        prefixed.mkpath unless @options.dryrun
        @log.debug( 'created : %s' % dir )
      else
        @log.debug( 'exists  : %s' % dir )
      end
    end

    def copy( filePath )
    # Copies a file
      origin = @options.input + @args[0] + filePath
      target = @options.output + filePath
      unless target.exist?
        FileUtils.cp( origin, target, :noop => @options.dryrun )
        @log.debug( 'copied  : %s' % filePath )
      else
        @log.debug( 'exists  : %s' % filePath )
      end
    end

    def consistent?( path, string )
    # Checks if a file has the correct type and architecture across all trees
      type_matches = true_for_all?( path, true ) {|filePath, arch|
        fileCallOutput = %x{ #{ $FILE } -b "#{ filePath }" }.chomp
        fileCallOutput.start_with?( string )
      }
      arch_matches = true_for_all?( path, true ) {|filePath, arch|
        lipoCallOutput = %x{ lipo -info "#{ filePath }" }.chomp
        lipoCallOutput.end_with?( 'is architecture: %s' % arch )
      }
      type_matches and arch_matches
    end

    def lipo( filePath )
    # Glues single-architecture files together using lipo(1)
      lipoArgs = Array.new
      @args.each {|arch|
        lipoArgs << '-arch %s %s' % [ arch, @options.input + arch + filePath ]
      }
      lipoTarget = @options.output + filePath
      lipoCommand = 'lipo %s -create -o %s' % [ lipoArgs.join( ' ' ), lipoTarget ]
      unless lipoTarget.exist?
        system lipoCommand unless @options.dryrun
        @log.debug( 'merged  : %s' % filePath )
      else
        @log.debug( 'exists  : %s' % filePath )
      end
    end

    def make_wrapper( filePath, first )
    # Creates a wrapper for a config script that differs across trees
      wrapperTarget = @options.output + filePath
      unless wrapperTarget.exist?
        wrapperTarget.open( 'w' ) {|wrapper|
          wrapper.puts(
            '#! /bin/sh',
            'DIR="/%s"' % filePath.dirname,
            'args=$@',
            'if [ "${args/-arch/}" != "$args" ]; then',
            %q{  arch=`echo "$args" | sed 's!.*-arch  *\([^ ][^ ]*\).*!\1!'`;},
            'else',
            '  arch=`uname -p`',
            'fi',
            'args=`echo $@ | sed "s!-arch  *${arch}!!"`',
            'exec $DIR/${arch}/%s ${args}' % filePath.basename
          )
        }
        wrapperTarget.chmod( first.stat.mode )
      end
    end

    def forked_copy( origin, target, logPath )
    # Copies files more flexibly than 'copy' at the cost of a clear interface
      unless target.exist?
        FileUtils.cp( origin, target, :noop => @options.dryrun )
        @log.debug( 'forked  : %s' % logPath )
      else
        @log.debug( 'exists  : %s' % logPath )
      end
    end

    public

    def handle_file( subPath )
      # Decides what action should be take for a file (skip/copy/merge) and
      # invokes the corresponding commands

      # firstPath is used so we have something we can compare other
      # architecture's versions of the file we are processing with.
      firstPath = @options.input + @args[0] + subPath
      unless true_for_all?( subPath, false ) {|filePath, arch|
        begin
          filePath.ftype == firstPath.ftype
        rescue Errno::ENOENT
          false
        end
      }
        # A file is either missing from at least one of the single-architecture
        # directories or not all versions of the file have the same type.
        @log.warn( 'skipped: %s' % subPath )
      else
        case firstPath.ftype
        # Handle file type: directory
        when 'directory'
          create_directory( @options.output, subPath )
        # Handle file type: symlink
        when 'link'
          firstLinkTarget = firstPath.readlink
          if true_for_all?( subPath, false ) {|filePath, arch|
            linkTarget = @options.input + arch + subPath
            linkTarget.readlink == firstLinkTarget
          }
            linkDestination = @options.output + subPath
            unless linkDestination.symlink? or linkDestination.exist?
              FileUtils.copy_entry( firstPath, linkDestination )
              @log.debug( 'copied  : %s' % subPath )
            else
              @log.debug( 'exists  : %s' % subPath )
            end
          else
            # The links point at different targets
            @log.warn( 'skipped: %s' % subPath )
          end
        when 'file'
          if true_for_all?( subPath, false ) {|filePath, arch|
            FileUtils.identical?( filePath, firstPath )
          }
            copy( subPath )
          else
            case subPath.extname
            # Handle file type: header file
            when '.h', '.hpp'
              unless ( @options.output + subPath ).exist?
                open( @options.output + subPath, 'w' ) {|headerTarget|
                  @args.each {|arch|
                    headerInput = @options.input + arch + subPath
                    headerTarget.puts(
                      '#ifdef __%s__' % arch,
                      headerInput.open( 'r' ).read,
                      '#endif'
                    )
                  }
                }
                @log.debug( 'merged  : %s' % subPath )
              else
                @log.debug( 'exists  : %s' % subPath )
              end
            # Handle file type: pkg-config file
            when '.pc'
              @args.each {|arch|
                subArch = subPath.dirname + arch + subPath.basename
                create_directory( @options.output, subArch.dirname )
                forked_copy(
                  @options.input + arch + subPath,
                  @options.output + subArch, subArch
                )
              }
            # Handle file type: gzip-compressed man page
            when '.gz'
              temporaryFiles = Hash.new
              @args.each {|arch|
                compressed = @options.input + arch + subPath
                uncompressed = Tempfile.new( compressed.basename )
                uncompressed.write( Zlib::GzipReader.open( compressed ).read )
                uncompressed.close
                temporaryFiles[arch] = uncompressed.path
              }
              if true_for_all?( subPath, false ) {|filePath, arch|
                FileUtils.identical?(
                  temporaryFiles[arch], temporaryFiles[@args[0]]
                )
              }
                copy( subPath )
              else
                # The content of the compressed files differs
                @log.warn( 'skipped: %s' % subPath )
              end
            else
              fileOutput = %x{ #{ $FILE } -b "#{ firstPath }" }.chomp
              case fileOutput
              # Handle file type: ar archive
              when %r{^current ar archive}
                if consistent?( subPath, 'current ar archive' )
                  lipo( subPath )
                else
                  @log.warn( 'skipped: %s' % subPath )
                end
              # Handle file type: mach-o binary
              when %r{^Mach-O}
                if consistent?( subPath, 'Mach-O' )
                  links = Hash.new
                  # Obtain the output of `otool -L`, get rid of everything we do
                  # not need and stuff it into a set for later comparison
                  @args.each {|arch|
                    links[arch] = %x{
                      #{
                        arch.end_with?( '64' ) ? 'otool64' : 'otool'
                      } -arch #{ arch } -LX #{
                        @options.input + arch + subPath
                      }
                    }.entries.collect {|library| library.lstrip }.reject {|line|
                      line.start_with?( '/usr/lib' )
                    }.to_set
                  }
                  unless true_for_all?( subPath, false ) {|filePath, arch|
                    links[arch] == links[@args[0]]
                  }
                    # At least one single-architecture file was linked against a
                    # library not all of the others were.
                    @log.warn( 'skipped: %s' % subPath )
                  else
                    lipo( subPath )
                  end
                else
                  @log.warn( 'skipped: %s' % subPath )
                end
              when 'Bourne shell script text executable'
                if subPath.basename.to_s.end_with?( '-config' )
                  # Handle file type: config script
                  @args.each {|arch|
                    subArch = subPath.dirname + arch + subPath.basename
                    create_directory( @options.output, subArch.dirname )
                    forked_copy(
                      @options.input + arch + subPath,
                      @options.output + subArch, subArch
                    )
                  }
                  make_wrapper( subPath, firstPath )
                  @log.debug( 'wrapped : %s' % subPath )
                end
              else
                # The file is a Bourne shell script, but we do not know how to
                # merge it.
                @log.warn( 'skipped: %s' % subPath )
              end
            end
          end
        end
      end
    end
  end


  def initialize
    @options = MergeArguments.parse( ARGV )

    # Ignore duplicates and trailing slashes
    @args = ARGV.collect {|arg| arg.chomp( '/' )}.uniq

    @ORIGIN = Pathname.pwd
    processed = Set.new

    # We need File with Apple's patches applied, otherwise we will not be able
    # to recognize x86_64 Mach-O files
    $FILE = '/usr/bin/file'

    # Start logging
    case @options.log
    when 'STDERR'
      @log = Logger.new( STDERR )
    when 'STDOUT'
      @log = Logger.new( STDOUT )
    else
      logTarget = Pathname.new( @options.log ).expand_path
      if logTarget.writable?
        @log = Logger.new( logTarget )
      elsif !logTarget.exist? and logTarget.dirname.writable?
        @log = Logger.new( logTarget )
      else
        @log = Logger.new( STDOUT )
        @log.error( 'cannot create log file' )
        raise( 'an error occurred.' )
      end
    end
    @log.level = @options.level
    @log.info( 'starting up' )

    # Make sure we are given a valid root directory
    unless @options.input.directory?
      @log.fatal( 'invalid input directory: %s' % @options.input )
      raise( 'an error occurred. see the log for details.' )
    end

    # Make sure the requested architectures have corresponding subdirectories
    # in the the given input directory
    unless true_for_all?( '.', true ) {|filePath, arch|
      filePath.directory?
    }
      @log.fatal( 'architecture missing from input directory' )
      raise( 'an error occurred. see the log for details.' )
    end

    # Walk the trees
    @args.each {|architecture|
      FileUtils.cd @options.input + architecture
      Pathname.new( '.' ).find {|subPath|
        @options.exclude.each {|excludedPattern|
          if subPath.basename.fnmatch? excludedPattern
            Find.prune
            break
          end
        }
        unless processed.include? subPath
          processed << subPath
          FileHandler.new( @options, @log, @args).handle_file( subPath )
        end
      }
    }

    FileUtils.cd @ORIGIN
    @log.info( 'shutting down' )
  end
end

Merge.new
