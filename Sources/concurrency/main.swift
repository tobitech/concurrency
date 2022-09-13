import Combine
import Foundation

// This is eager by default, so as soon as you create the `Future` publisher, it starts doing its work.
//let publisher = Future<Int, Never> { callback in
//  print(Thread.current)
//  callback(.success(42))
//}

// Wrapp it with a Deferred publisher to make it lazy just like we needed to call start on Threads, needed to send a BlockOperation to an OperationQueue, needed to send a work item to a DispatchQueue.
let publisher1 = Deferred {
  Future<Int, Never> { callback in
    print(Thread.current)
    callback(.success(42))
  }
}
  .subscribe(on: DispatchQueue(label: "queue1"))

let publisher2 = Deferred {
  Future<String, Never> { callback in
    print(Thread.current)
    callback(.success("Hello, world!"))
  }
}
  .subscribe(on: DispatchQueue(label: "queue2"))

// in order to get access to the returned value we can subscribe to the publisher with sink()
// we need to hold on to the cancellable it returns as long as the publisher is alive, in order to keep getting values from it.
let cancellable = publisher1
// this shows how we can easily start another work when one finishes
  .flatMap { integer in
    Deferred {
      Future<String, Never> { callback in
        print(Thread.current)
        callback(.success("\(integer)"))
      }
    }
    .subscribe(on: DispatchQueue(label: "queue3"))
  }
// this shows the power of combine in coordinating two units of work and gettint their results when they both finish.
  .zip(publisher2)
  .sink {
    print("sink", $0, Thread.current) // returns a tuple of (Int, String)
  }

// without subscribe(on:)
//<_NSMainThread: 0x10710aac0>{number = 1, name = main}
//sink 42 <_NSMainThread: 0x10710aac0>{number = 1, name = main}

// when we used subscribe(on:)
//<NSThread: 0x101504930>{number = 3, name = (null)}
//<NSThread: 0x101238470>{number = 2, name = (null)}
//<NSThread: 0x101504930>{number = 3, name = (null)}
//sink ("42", "Hello, world!") <NSThread: 0x101504930>{number = 3, name = (null)}

_ = cancellable

Thread.sleep(forTimeInterval: 2)
