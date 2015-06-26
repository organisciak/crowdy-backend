import boto.mturk.connection
import urllib
import json
import logging


def main():
    logging.basicConfig(file="creating-tasks.log", level=logging.INFO)

    with open("task1.json", "rb") as task:
        config = json.loads(task.read())

    sandbox_host = 'mechanicalturk.sandbox.amazonaws.com'
    real_host = 'mechanicalturk.amazonaws.com'

    mturk = boto.mturk.connection.MTurkConnection(
        host=sandbox_host,
        debug=1  # debug = 2 prints out all requests.
    )

    questionform = boto.mturk.question.ExternalQuestion(
        "%s?%s" % (config['url'],
                   urllib.urlencode(config['params'])),
        config['frame_height'])

    hit_type = mturk.register_hit_type(
        title=config['title'],
        description=config['description'],
        reward=boto.mturk.price.Price(config['amount']),
        duration=60*60,  # in seconds
        keywords=config['keywords'],
        approval_delay=1.5*24*60*60  # seconds
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
