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

// _ = cancellable

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
  
  operationA.cancel()
  
  //A ➡️ B
  //⬇️    ⬇️
  //C ➡️ D
}

// let's look at what it looks like to make the cyclical dependency in combine.
// let's say you have a publisher `a`
// this is an extremely compact way of expressing a complex dependency relationship between streams of values.
// this gets at the heart of what Swift's new concurrency tools wants to accomplish.
//a
//  .flatMap { a in
//    zip(b(a), c(a)) // concurrenlty running two units of work (or in parallel)
//  }
//  .flatMap { (b, c) in
//    d(b, c)
//  }

// This is what we would be able to achieve once we get familiar with Swift's new concurrency APIs.
// writing complex asynchronous code the way we normally write our normal synchronous codes in our everyday programming.
//let a = await f()
//async let b = g(a)
//async let c = h(a)
//let d = await i(b, c)


//defer { print("Finished") }
//guard let a = await f()
//else { return }
//async let b = g(a)
//async let c = h(a)
//let d = await i(b, c)


func dispatchDiamondDependency() {
  let queue = DispatchQueue(label: "queue", attributes: .concurrent)
  queue.async {
    print("A")
    
    let group = DispatchGroup()
    queue.async(group: group) {
      print("B")
    }
    queue.async(group: group) {
      print("C")
    }
    
    group.notify(queue: queue) {
      print("D")
    }
  }
  
  //A ➡️ B
  //⬇️    ⬇️
  //C ➡️ D
}

// Thread.sleep(forTimeInterval: 2)
