import Foundation

func operationQueueBasics() {
  // this acts as the arbiter of execution for many units of work:
  let operation = OperationQueue()
  
  operation.addOperation {
    print(Thread.current)
  }
  
  // similar to Threads, the order or execution is not guaranteed
  operation.addOperation { print("1", Thread.current) }
  operation.addOperation { print("2", Thread.current) }
  operation.addOperation { print("3", Thread.current) }
  operation.addOperation { print("4", Thread.current) }
  operation.addOperation { print("5", Thread.current) }
}

func operationPriorityAndCancellation() {
  // let's eplore setting priorities on an operation.
  // to do that we have to hold on to the operation before handing it off to an operation queue.
  // to do that we have to create an instance of the operation class which means it needs to be subclassed, but Apple ships some subclasses we can use.
  
  // now we have access to the operation and we can use it inside the block
  let operation = BlockOperation()
  
  // this creates a retain-cycle because the closure is hold by the operation, and the closure is also referencing the operation inside of the block, so we need to weakify it or use unowned.
  // this is how to do cooperative cancellation.
  operation.addExecutionBlock { [unowned operation] in
    
    // running this to demonstrate that program ran for 1.0sec even though we cancelled it after 0.1sec
    let start = Date()
    defer { print("Finished", Date().timeIntervalSince(start)) }
    
    // It’s worth pointing that although cancellation is cooperative, the cooperation is not deeply ingrained in the system. Here we cancelled the task after 0.1 seconds, but the thread is still going to sleep for the full 1 second before continuing. There is no way to interrupt that sleeping:
    Thread.sleep(forTimeInterval: 1)
    guard !operation.isCancelled else {
      print("Cancelled!")
      return // short-circuit any other work.
    }
    print(Thread.current)
  }
  
  let queue = OperationQueue()
  
  // they call their own `qualityOfService` rather than priority which is a value from 0 and 1.
  operation.qualityOfService = .background
  
  queue.addOperation(operation)
  
  Thread.sleep(forTimeInterval: 0.1) // to make sure it officially started.
  // cancel the operation.
  // we still get the print statements.
  // like Thread, operation is cancellation is cooperative.
  // it is up to us as good citizens to be checking if the item has been cancelled, so that we can short-circuit the remaining work that is left to be done.
  operation.cancel()
}

func operationQueueCoordination() {
  let queue = OperationQueue()
  
  // create an operation that will run on the queue above.
  let operationA = BlockOperation {
    print("A")
    Thread.sleep(forTimeInterval: 1)
  }
  
  let operationB = BlockOperation {
    print("B")
  }
  
  let operationC = BlockOperation {
    print("C")
  }
  
  let operationD = BlockOperation {
    print("D")
  }
  
  // make operationB be dependent on operationA.
  // this means operationB will not be started until operationA finishes
  operationB.addDependency(operationA)
  operationC.addDependency(operationA)
  operationD.addDependency(operationB)
  operationD.addDependency(operationC)
  
  queue.addOperation(operationA)
  queue.addOperation(operationB)
  queue.addOperation(operationC)
  queue.addOperation(operationD)
  
  //A ➡️ B
  //⬇️    ⬇️
  //C ➡️ D
}

let queue = OperationQueue()

// let's see what happens if we add 1,000 operations to the queue
for n in 0..<workcount {
  queue.addOperation {
    // we're going to hold on for the thread created here just so that we can wait for time to pass.
    // Thread.sleep(forTimeInterval: 1)
    // we got not more than 70 threads spun up, meaning about 70 threads to run 1,000 operations.
    // this is a good thing, because operation queus are working like the thread pool concept we discussed in the last episode.
    print(n, Thread.current)
    while true {}
  }
}

// this wasn't printed, because operation queue didn't allow for 1,000 threads to be created and because the time we slept for wasn't enough for the work to be done.
// so it just blocks the queue and prevents other operations in the queue from runnning.
queue.addOperation {
  print("Starting the prime operation")
  nthPrime(50_000)
}

Thread.sleep(forTimeInterval: 2)
