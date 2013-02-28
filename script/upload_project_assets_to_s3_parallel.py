import optparse
import os
import glob
import re
import shutil

from s3_parallel_put import main as parallel_upload

S3_ACCESS_KEY_ID = ENV['S3_ACCESS_KEY_ID']
S3_SECRET_ACCESS_KEY = ENV['S3_SECRET_ACCESS_KEY']

def upload_build(project_name):
    os.environ['AWS_ACCESS_KEY_ID'] = S3_ACCESS_KEY_ID
    os.environ['AWS_SECRET_ACCESS_KEY'] = S3_SECRET_ACCESS_KEY

    parallel_upload_command = ['s3-parallel-put.py', '--insecure', '--bucket=hubspot-static2cdn', '--put=stupid', '--grant=public-read', '--quiet', '--content-type=guess']
    parallel_upload_pointers_command = ['s3-parallel-put.py', '--insecure', '--bucket=hubspot-static2cdn', '--put=stupid', '--grant=public-read', '--quiet', '--content-type=text/plain']

    # Upload the archives first to ensure they are fully uploaded
    # before the "pointer" files are changed (to prevent update-deps
    # from trying to download non-fully baked static archives)
    archive_files = glob.glob("%(project_name)s*.tar.gz" % locals())
    cmd = parallel_upload_command + ['--processes=2'] + archive_files
    print "\nUploading archive files: %s ..." % ', '.join(archive_files)
    parallel_upload(cmd)

    # Next upload all the static assets (both debug and compressed folders)
    static_build_folders = glob.glob('%(project_name)s/static-*' % locals())
    cmd = parallel_upload_command + ['--processes=16'] + static_build_folders
    print "\nUploading all static files ..."
    parallel_upload(cmd)

    # Lastly upload all of the "pointer" files (so that everything is in
    # place before the pointers are changed)
    pointer_files = glob.glob("%(project_name)s/current*" % locals()) + \
                    glob.glob("%(project_name)s/edge*" % locals()) + \
                    glob.glob("%(project_name)s/latest*" % locals())

    cmd = parallel_upload_pointers_command + ['--processes=4'] + pointer_files
    print "\nUploading all pointers: %s ..." % ', '.join(pointer_files)
    parallel_upload(cmd)


# Note, this is expected to be run in the current directory of the compiled output
def main():
    parser = optparse.OptionParser()
    parser.add_option('-p', '--project-name', dest='project_name')
    options, args = parser.parse_args()
    upload_build(options.project_name)

if __name__ == "__main__":
    main()

