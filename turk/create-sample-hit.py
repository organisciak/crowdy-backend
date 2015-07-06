from boto.mturk import connection, qualification, price, question
import urllib
import json
import logging
import argparse


def main():
    logging.basicConfig(file="creating-tasks.log", level=logging.INFO)
    parser = argparse.ArgumentParser()
    parser.add_argument('taskFile', type=str, help="JSON of task params")
    parser.add_argument('--production', action='store_true')
    parser.add_argument('--no-quals', action='store_true')
    args = parser.parse_args()

    with open(args.taskFile, "rb") as task:
        config = json.loads(task.read())

    if args.production:
        host = 'mechanicalturk.amazonaws.com'
    else:
        host = 'mechanicalturk.sandbox.amazonaws.com'

    mturk = connection.MTurkConnection(
        host=host,
        debug=1  # debug = 2 prints out all requests.
    )

    # Question
    questionform = question.ExternalQuestion(
        "%s?%s" % (config['url'],
                   urllib.urlencode(config['params'])),
        config['frame_height'])

    # Qualifications
    quals = qualification.Qualifications()
    if not args.no_quals:
        quals.add(qualification.LocaleRequirement(
            "EqualTo", "US", required_to_preview=True)
            )
        quals.add(qualification.NumberHitsApprovedRequirement(
            'GreaterThanOrEqualTo', 20, required_to_preview=True)
            )
        quals.add(qualification.PercentAssignmentsApprovedRequirement(
            'GreaterThanOrEqualTo', 95, required_to_preview=True)
            )

    hit_type = mturk.register_hit_type(
        title=config['title'],
        description=config['description'],
        reward=price.Price(config['amount']),
        duration=30*60,  # in seconds
        keywords=config['keywords'],
        approval_delay=1.5*24*60*60,  # seconds
        qual_req=quals
    )

    assert hit_type.status

    hittype_id = hit_type[0].HITTypeId

    logging.info("\t".join(["HITTypeId", "HITId", "Annotation", "Amount"]))
    for i in xrange(config['num_hits']):
        create_hit_result = mturk.create_hit(
            hit_type=hittype_id,
            question=questionform,
            annotation=config['annotation'],
            max_assignments=config['max_assignments'],
        )

        HIT = create_hit_result[0]
        assert create_hit_result.status

        logging.info("\t".join([hittype_id,
                                HIT.HITId,
                                config['annotation'],
                                str(config['amount'])
                                ]))

if __name__ == "__main__":
    main()
