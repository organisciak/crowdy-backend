'''
    Expire all your HITs.

    This is the 'oh shit, shouldn't have clicked that' option, when you are
    scrambling to fix it. Good to have it programmed before you need it!

'''
import boto.mturk.connection
import logging

def main():
    logging.basicConfig(file="expiring-tasks.log", level=logging.INFO)

    sandbox_host = 'mechanicalturk.sandbox.amazonaws.com'
    real_host = 'mechanicalturk.amazonaws.com'

    mturk = boto.mturk.connection.MTurkConnection(
        host=sandbox_host,
        debug=1  # debug = 2 prints out all requests.
    )

    page_hits = mturk.get_all_hits()
    for HIT in page_hits:
        logging.info("Deleting:"+HIT.HITId+'\t'+HIT.HITTypeId)
        mturk.expire_hit(HIT.HITId)
    return

if __name__ == "__main__":
    main()