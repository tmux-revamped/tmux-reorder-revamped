#!/bin/sh

reorder_revamped_dir=$(cd "$(dirname "$0")" && pwd)
"${reorder_revamped_dir}/bin/reorder-revamped" apply
