require 'asset_bender_test'

describe AB::ProcUtils do

  before(:each) do
    @proc_utils = AB::ProcUtilsInstance.new

    class SomeObj
      def always_error
        puts "always error"
        raise "fake error"
      end

      def nil_for_you
        nil
      end

      def gimmie_an_int
        42
      end
    end

    @some_obj = SomeObj.new
  end

  context 'when call_if_proc_otherwise_self is called' do
    it 'should return a value with an int' do
      @proc_utils.call_if_proc_otherwise_self(3).should eq(3)
    end

    it 'should return a value with a string' do
      @proc_utils.call_if_proc_otherwise_self("five").should eq("five")
    end

    it 'should call a lambda' do
      l = lambda { "hello" }
      @proc_utils.call_if_proc_otherwise_self(l).should eq("hello")
    end

    it 'should call a proc' do
      p = Proc.new { "stay thirsty my " + "friend" }
      @proc_utils.call_if_proc_otherwise_self(p).should eq("stay thirsty my friend")
    end
  end

  context 'when retry_up_to is called' do

    it 'should retry up to X times if erroring' do
      @some_obj.should_receive(:always_error).at_least(3).times.and_call_original
      expect { @proc_utils.retry_up_to(3) { @some_obj.always_error } }.to raise_error
    end

    it 'should retry up to X times if nil result' do
      @some_obj.should_receive(:nil_for_you).at_least(3).times.and_call_original
      @proc_utils.retry_up_to(3) { @some_obj.nil_for_you }
    end

    it 'should not retry if a valid value is returned' do
      @some_obj.should_receive(:always_error).at_most(1).times.and_call_original
      @proc_utils.retry_up_to(3) { @some_obj.gimmie_an_int }
    end
  end

end