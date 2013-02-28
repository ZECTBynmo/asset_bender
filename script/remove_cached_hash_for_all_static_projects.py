import os
import glob
import re
import shutil
import sys

from boto.s3.connection import S3Connection
from boto.s3.key import Key

S3_ACCESS_KEY_ID = ENV['S3_ACCESS_KEY_ID']
S3_SECRET_ACCESS_KEY = ENV['S3_SECRET_ACCESS_KEY']

MAX_MAJOR_VERSION_NUMBER = 20

def remove_hashes(projects=None):
    if not projects:
        raise Exception("You must pass at least one project name as an argument!")

    conn = S3Connection(aws_access_key_id=S3_ACCESS_KEY_ID,
                        aws_secret_access_key=S3_SECRET_ACCESS_KEY)
    bucket = conn.get_bucket('hubspot-static2cdn')

    potential_pointers = [
        'current-qa',
        'latest-qa',
        'edge-qa'
    ] + ["latest-version-%i-qa" % i for i in range(MAX_MAJOR_VERSION_NUMBER)]

    for project_name in projects:
        print "Searching for all the current builds for %s (note, this is currently limited to max version # of %i)" % (project_name, MAX_MAJOR_VERSION_NUMBER)

        pointer_keys = []

        for potential_pointer in potential_pointers:
            key = bucket.get_key('%s/%s' % (project_name, potential_pointer))

            if key:
                pointer_keys.append(key)

        current_builds = set([x.get_contents_as_string().strip() for x in pointer_keys])

        if not current_builds:
            raise Exception("Couldn't find any builds for %s" % project_name)

        else:
            print "Removing the prebuilt has for these versions: %s" % (', '.join(current_builds))

            prebuilt_hash_keys = []
            for build in current_builds:
                key = bucket.get_key('%s/%s/premunged-static-contents-hash.md5' % (project_name, build))

                if key:
                    prebuilt_hash_keys.append(key)

            if not prebuilt_hash_keys:
                print "All prebuilt hash keys have already been removed.\n"
            else:
                for key in prebuilt_hash_keys:
                    key.delete()

                print "Done!\n"


def main():
    projects = sys.argv[1:]
    remove_hashes(projects)

if __name__ == "__main__":
    main()

