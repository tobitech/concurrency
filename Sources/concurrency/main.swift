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

func dispatchPriorityAndCancellation() {
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
}

func makeDatabaseQuery() {
  let requestId = DispatchQueue.getSpecific(key: requestIdKey)!
  print(requestId, "Making database query")
  Thread.sleep(forTimeInterval: 0.5)  // simulate the idea of making a database query by sleeping for 0.5sec
  print(requestId, "Finished database query")
}

func makeNetworkRequest() {
  let requestId = DispatchQueue.getSpecific(key: requestIdKey)!
  print(requestId, "Making network request")
  Thread.sleep(forTimeInterval: 0.5)
  print(requestId, "Finished network request")
}

// we are passing along the queue so that we can use it to target the other child queues and have access to the `specifics`.
func response(for request: URLRequest, queue: DispatchQueue) -> HTTPURLResponse {
  // TODO: do the work to turn request into a response
  // somehow it finds a way to know what queue we're operating on and get the specific key.
  let requestId = DispatchQueue.getSpecific(key: requestIdKey)!
  
  let start = Date()
  defer { print("Finished in", Date().timeIntervalSince(start)) }
  
  // this is used for coordination. it allows us to treat multiple unit of work as just a single unit of work.
  // if we don't use this, because the databaseQueue and networkQueue are non-blocking it will just breeze past them and return an empty HTTPURLResponse.
  // so we need a way to wait for the two works to be completed.
  let group = DispatchGroup()
  
  // so now we can do some units of work, to generate the response e.g. database query, network request, wrap each of them with a log, so we know what is happening on the inside of this request lifecycle.
  let databaseQueue = DispatchQueue(label: "database-query", target: queue)
  // invoking async on this queue is a non-blocking operation
  databaseQueue.async(group: group) {
    makeDatabaseQuery()
  }
  
  let networkQueue = DispatchQueue(label: "network-request", target: queue)
  networkQueue.async(group: group) {
    makeNetworkRequest()
  }
  
  // remember for threads we had to do some polling to check if the two operations had finished before we could return a response.
  // DispatchGroup is a nice tool for coordination here.
  group.wait()
  
  // TODO: return real response
  return .init()
}

// we can create a single queue, when the server first loads up.
let serverQueue = DispatchQueue(label: "server-queue", attributes: .concurrent)

let requestIdKey = DispatchSpecificKey<UUID>()
let requestId = UUID()
// remember to set concurrent attribute to make it the work sent to it happen in parallel
let requestQueue = DispatchQueue(label: "request-\(requestId)", attributes: .concurrent, target: serverQueue)

// This allows us to pluck the request ID out of thin air without having to explicitly pass it through every single layer:
// as long as we are operating within the execution context of this `queue`, we will have access to it.
requestQueue.setSpecific(key: requestIdKey, value: requestId)

let item = DispatchWorkItem {
  response(for: .init(url: .init(string: "http://pointfree.co")!), queue: requestQueue)
}

requestQueue.async(execute: item)

let queue1 = DispatchQueue(label: "queue1")
let idKey = DispatchSpecificKey<Int>()
let dateKey = DispatchSpecificKey<Date>()
queue1.setSpecific(key: idKey, value: 42)
queue1.setSpecific(key: dateKey, value: Date())

queue1.async {
  print("queue1", "id", DispatchQueue.getSpecific(key: idKey))
  print("queue1", "date", DispatchQueue.getSpecific(key: dateKey))
  
  // let queue2 = DispatchQueue(label: "queue2")
  // setting a target is how it would inherit the specifics of the queue it's targetting.
  let queue2 = DispatchQueue(label: "queue2", target: queue1)
  queue2.setSpecific(key: idKey, value: 1729)
  queue2.async {
    print("queue2", "id", DispatchQueue.getSpecific(key: idKey))
    // specifics are not automatically inherited when you start a new queue inside the execution context of another queue.
    print("queue2", "date", DispatchQueue.getSpecific(key: dateKey)) // nil
  }
}

Thread.sleep(forTimeInterval: 2)
