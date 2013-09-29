# The response files for FakeWeb were generated as follows.
# Setting XXX and YYY to either valid or invalid django_auth credentials,
#   and setting USER:PASS to the valid or invalid BasicAuth username/password:
# For testing authentication:
# curl --include --silent --user 'USER:PASS' \
#      --cookie-jar /tmp/cookies.txt'  \
#      --data 'username=XXX' --data 'password=YYY' \
#      https://xqueue.edx.org/xqueue/login/
# For testing queue length:

require 'x_queue'

describe XQueue do

  describe 'base URI' do
    after(:all) { XQueue.base_uri = XQueue::XQUEUE_DEFAULT_BASE_URI }
    it 'has a default' do
      XQueue.base_uri.to_s.should_not be_empty
    end
    it 'can be changed to a valid URI' do
      expect { XQueue.base_uri = 'http://my.com/URI' }.not_to raise_error
      XQueue.base_uri.should == URI('http://my.com/URI')
    end
    it 'cannot be changed to an invalid URI' do
      expect { XQueue.base_uri = '12%' }.to raise_error(URI::InvalidURIError)
    end
  end

  describe 'new' do
    subject { XQueue.new('django_user', 'django_pass', 'user', 'pass', 'my_q') }
    its(:queue_name) { should == 'my_q' }
    its(:base_uri)   { should == URI('https://xqueue.edx.org') }
  end

end

