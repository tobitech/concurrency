import Foundation

// It turns out threads are not started in the same way they were created.

func threadBasics() {
  Thread.detachNewThread {
    print("1", Thread.current)
  }
  
  Thread.detachNewThread {
    print("2", Thread.current)
  }
  
  Thread.detachNewThread {
    print("3", Thread.current)
  }
  
  Thread.detachNewThread {
    print("4", Thread.current)
  }
  
  Thread.detachNewThread {
    print("5", Thread.current)
  }
}

func threadPriorityAndCancellation() {
  let thread = Thread {
    // we work we do in this closure is lazy.
    
    // to demonstrate how long the Thread slept for
    let start = Date()
    defer { print("Finished in", Date().timeIntervalSince(start)) }
    
    // this doesn't perticipate in cooperative cancellation, so it will wait it full time even though it's cancelled.
    Thread.sleep(forTimeInterval: 1)
    
    Thread.detachNewThread {
      print("Inner thread cancelled?", Thread.current.isCancelled)
    }
    
    // this is how co-operative cancellation works.
    
    guard !Thread.current.isCancelled else {
      print("Cancelled!")
      return
    }
    
    print(Thread.current) // print out what thread we're on.
  }
  
  // this allows us to set thread priority: a Double value between 0 and 1
  // This will signal to the operating system that this thread is low or high priority, and perhaps the OS will give the thread a little bit less or more time to execute relative to other threads, though there are no guarantees.
  thread.threadPriority = 0.75
  
  // we need to explicitly start the thread since the work is lazy.
  // otherwise the program exits immediately.
  thread.start()
  
  // this should give the thread just enough time to start execution
  // otherwise the os just doesn't bother to start the thread since it was cancelled immediately.
  Thread.sleep(forTimeInterval: 0.01)
  
  // this allows us to cancel a thread
  thread.cancel()
}

func threadStorageAndCoordination() {
  func makeDatabaseQuery() {
    let requestId = Thread.current.threadDictionary["requestId"] as! UUID
    print(requestId, "Making database query")
    Thread.sleep(forTimeInterval: 0.5) // to simulate database operation.
    print(requestId, "Finished database query")
  }
  
  func makeNetworkRequest() {
    let requestId = Thread.current.threadDictionary["requestId"] as! UUID
    print(requestId, "Making network request")
    Thread.sleep(forTimeInterval: 0.5) // to simulate network operation.
    print(requestId, "Finished network request")
  }
  
  // in an oversimplified world, let's think of a server as a function from request to response.
  func response(for request: URLRequest) -> HTTPURLResponse {
    // TODO: do the real work
    
    // this can be accessed from anywhere
    let requestId = Thread.current.threadDictionary["requestId"] as! UUID
    
    // to find out how long did the entire request take.
    let start = Date()
    defer { print(request, "Finished in", Date().timeIntervalSince(start)) }
    
    // we didn't have to pass in the `requestId` into this function,
    // we can just pluck it out of thin here inside the functions.
    // with database query now running in another thread we no longer have access to the requestId on the threadDictionary and so it crashes.
    let databaseQueryThread = Thread { makeDatabaseQuery() }
    // whenever we spin off a new thread, we need to explicitly copy over the current threadDictionary
    // the reason we're having to do this is because Threads don't have the concept of a child Threads i.e. creating a new thread leads to a whole new isolated thread without inheriting anything from the thread from which is was created. that includes, priority, threadDictionary and more.
    databaseQueryThread.threadDictionary.addEntries(from: Thread.current.threadDictionary as! [AnyHashable : Any])
    databaseQueryThread.start()
    let networkRequestThread = Thread { makeNetworkRequest() }
    networkRequestThread.threadDictionary.addEntries(from: Thread.current.threadDictionary as! [AnyHashable : Any])
    networkRequestThread.start()
    
    // TODO: join threads somehow
    // we want to wait for the two new threads to finishe so that we can join the results together. Thread class doesn't provide a way to do this. so we can improvise to achieve that.
    // this is a narly logic and a huge bummer.
    while !databaseQueryThread.isFinished || !networkRequestThread.isFinished {
      Thread.sleep(forTimeInterval: 0.1) // add more sleep to wait for the two threads
    }
    
    return HTTPURLResponse()
  }
  
  //for _ in 0..<10 {
  let thread = Thread {
    response(for: URLRequest(url: URL(string: "http://pointfree.co")!))
  }
  
  // when you set a value in this threadDictionary, it is available from any executed code running on that thread.
  thread.threadDictionary["requestId"] = UUID()
  thread.start()
  //}
}

let workcount = 1_000

for n in 0..<workcount {
  let thread = Thread.detachNewThread {
    print(n, Thread.current)
    // simulate serious work of downloading a web page and decoding, parsing and indexing by throwing in an infinite loop.
    while true {}
    
  }
}

Thread.sleep(forTimeInterval: 3)
