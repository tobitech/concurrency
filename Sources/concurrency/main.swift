import Combine
import Foundation

// This is eager by default, so as soon as you create the `Future` publisher, it starts doing its work.
//let publisher = Future<Int, Never> { callback in
//  print(Thread.current)
//  callback(.success(42))
//}

// Wrapp it with a Deferred publisher to make it lazy just like we needed to call start on Threads, needed to send a BlockOperation to an OperationQueue, needed to send a work item to a DispatchQueue.
let publisher = Deferred {
  Future<Int, Never> { callback in
    print(Thread.current)
    callback(.success(42))
  }
}

// in order to get access to the returned value we can subscribe to the publisher with sink()
// we need to hold on to the cancellable it returns as long as the publisher is alive, in order to keep getting values from it.
let cancellable = publisher.sink {
  print("sink", $0, Thread.current)
}

//<_NSMainThread: 0x10710aac0>{number = 1, name = main}
//sink 42 <_NSMainThread: 0x10710aac0>{number = 1, name = main}

_ = cancellable

Thread.sleep(forTimeInterval: 2)
