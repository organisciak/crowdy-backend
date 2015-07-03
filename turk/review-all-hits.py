'''
    Approve all reviewable HITs.

'''
import boto.mturk.connection
import logging
import argparse


def main():
    logging.basicConfig(file="review-tasks.log", level=logging.INFO)
    parser = argparse.ArgumentParser()
    parser.add_argument('--production', action='store_true')
    parser.add_argument('--autoapprove', action='store_true')
    args = parser.parse_args()

    if args.production:
        host = 'mechanicalturk.amazonaws.com'
    else:
        host = 'mechanicalturk.sandbox.amazonaws.com'

    mturk = boto.mturk.connection.MTurkConnection(
        host=host,
        debug=1  # debug = 2 prints out all requests.
    )

    page_hits = mturk.get_reviewable_hits()
    for HIT in page_hits:
        assignments = mturk.get_assignments(HIT.HITId)
        for assignment in assignments:
            if args.autoapprove:
                logging.info("Auto-approving:%s\t%s" % (
                    HIT.HITId, assignment.AssignmentId))
                try:
                    mturk.approve_assignment(assignment.AssignmentId)
                except Exception:
                    logging.exception("Approval error")
    return

if __name__ == "__main__":
    main()
