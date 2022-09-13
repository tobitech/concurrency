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
let item = DispatchWorkItem {
  print(Thread.current)
}

queue.async(execute: item)


Thread.sleep(forTimeInterval: 2)
