import optparse
import os
import glob
import re
import shutil

from boto.s3.connection import S3Connection
from boto.s3.key import Key


S3_ACCESS_KEY_ID = ENV['S3_ACCESS_KEY_ID']
S3_SECRET_ACCESS_KEY = ENV['S3_SECRET_ACCESS_KEY']

def upload_file(bucket, file, dirpath=None):
    if dirpath:
        path = dirpath + '/' + file
    else:
        path = file

    key = bucket.new_key()
    key.key = '/' + path

    #key.content_type = mime_type
    with open(path) as f:
        key.set_contents_from_file(f, policy='public-read')

def upload_build(project_name):
    conn = S3Connection(aws_access_key_id=S3_ACCESS_KEY_ID,
                        aws_secret_access_key=S3_SECRET_ACCESS_KEY)
    bucket = conn.get_bucket('hubspot-static2cdn')

    # Upload the archives first to ensure they are fully uploaded
    # before the "pointer" files are changed (to prevent update-deps
    # from trying to download non-fully baked static archives)
    for archive_file in glob.glob("%s*.tar.gz" % project_name):
        upload_file(bucket, archive_file)

    # walk the directory and upload everything
    for dirpath, dirs, files in os.walk(project_name):
        # skip the top level files (current-qa, latest-qa) until everything else is uploaded
        if dirpath == project_name:
            continue
        for file in files:
            upload_file(bucket, file, dirpath=dirpath)
    # Now upload the top level files
    for file in os.listdir(project_name):
        if os.path.isfile(project_name + '/' + file):
            upload_file(bucket, file, dirpath=project_name)


def main():
    parser = optparse.OptionParser()
    parser.add_option('-p', '--project-name', dest='project_name')
    options, args = parser.parse_args()
    upload_build(options.project_name)

if __name__ == "__main__":
    main()

