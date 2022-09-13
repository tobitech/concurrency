import Foundation

func dispatchBasics() {
  // for GCD, you think of concurrency in terms of queueus rather than in terms of threads.
  
  // to start you start by creating a dispath queue.
  // adding .concurrent attribute, make it run the added work concurrently an on different threads.
  let queue = DispatchQueue(label: "my.queue", attributes: .concurrent)
  
  // then you can send units of work to the queue to be performed.
  // this allows us to queue up some asynchronous work.
  // by
  //queue.async {
  //  print(Thread.current)
  //}
  
  //queue.async { print("1", Thread.current) }
  //queue.async { print("2", Thread.current) }
  //queue.async { print("3", Thread.current) }
  //queue.async { print("4", Thread.current) }
  //queue.async { print("5", Thread.current) }
  
  // the units of work are run sequentially in order
  // and also all on the same thread.
  // this is happening because DispatchQueues are serial by default.
  //<NSThread: 0x10110c4a0>{number = 2, name = (null)}
  //1 <NSThread: 0x10110c4a0>{number = 2, name = (null)}
  //2 <NSThread: 0x10110c4a0>{number = 2, name = (null)}
  //3 <NSThread: 0x10110c4a0>{number = 2, name = (null)}
  //4 <NSThread: 0x10110c4a0>{number = 2, name = (null)}
  //5 <NSThread: 0x10110c4a0>{number = 2, name = (null)}
  
  // just like operation queues, dispatch queues fixes the problem of thread explosion.
  // just few threads about 60 needed to run 1,000 units of work.
  //for n in 0..<workcount {
  //  queue.async { print(n, Thread.current) }
  //}
  
  // instead of sleeping a thread for a while which unnecessarily takes up resoures
  // dispatch queue can schedule work to be done in the future.
  print("before scheduling")
  queue.asyncAfter(deadline: .now() + 1) {
    print("1 second passed")
  }
  print("after scheduling")
}

// priority is done by specifying a quality of service (qos)
let queue = DispatchQueue(label: "my.queue", qos: .background)

// you can also get a hold of the unit of work performed just like operation queues by building up a `DispatchWorkItem`.
var item: DispatchWorkItem!
// we can't use a capture list in the closure for this one, because the capture list eagerly captures it and because we haven't instantiated it with a value (implicitly unwrapped optional), what is captured is a nil value.

item = DispatchWorkItem {
  // this helps with the cyclical dependency that has been introduced.
  // this should release that item from any kind of retain cycle.
  defer { item = nil }
  
  let start = Date()
  defer { print("Finished in", Date().timeIntervalSince(start)) }
  
  Thread.sleep(forTimeInterval: 1)
  guard !item.isCancelled else {
    print("Cancelled!")
    return
  }
  print(Thread.current)
}

queue.async(execute: item)

Thread.sleep(forTimeInterval: 0.5)

// cancel a work item.
// cancellation is also cooperative, it's up to us to be good citizens by regularly checking if the work item has been cancelled so that we can short-circuit the remaining work that needs to be done.
item.cancel()


Thread.sleep(forTimeInterval: 2)
