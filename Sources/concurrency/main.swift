import Foundation

// Unstructured Tasks inherit Task locals from the current Task context
enum MyLocals {
	@TaskLocal static var id: Int!
}

//print("before:", MyLocals.id)
//MyLocals.$id.withValue(42) {
//	print(("withValue:", MyLocals.id!))
//
//	// Even though we spinned off an unstructured Task, it inherited the local.
//	Task {
//		print("Task:", MyLocals.id!)
//	}
//}
//print("after:", MyLocals.id)

// Even though
//before: nil
//("withValue:", 42)
//after: nil
//Task: 42


// In addition to locals, Tasks inherit other things too, such as priority.
// We can see this by nesting a few Tasks and printing out thier priority
//print(Task.currentPriority)
//Task(priority: .low) {
//	print(Task.currentPriority)
//	Task {
//		print(Task.currentPriority)
//	}
//}

// Ouput
//TaskPriority(rawValue: 33)
//TaskPriority(rawValue: 17)
//TaskPriority(rawValue: 17)


// There is a 3rd thing that Tasks inherit and that is the actor context of the caller.
// let's revisit the example of using an actor when we were exploring data races.
// suppose we want to add a really silly feature to this counter so that if you decrement below 0, it will increment back up, but we'll do so after a small delay.
actor Counter {
	var count = 0
	
	func increment() {
		self.count += 1
	}
	
	func decrement() {
		self.count -= 1
		// This is compiling only because the Task is inheriting the current actor context.
		// And this compiles. But perhaps it’s a little surprising that it compiles.
		// After all, so far whenever we have tried accessing methods and properties on actors we have be forced to await it:
		// The only exception was when writing code directly in the actor:
		// Now technically the task code is inside the actor, but as we’ve noted before, the closure used in the task initializer is an @escaping and @Sendable closure, which means for all intents and purposes it really is its own execution context. How on earth is it possible that we are able to reach out from this escaped context and access the actor’s properties without having to await for synchronization?
		// This is possible specifically because this task inherits its actor’s context. It is allowed to interact with the actor as if it was code written directly in a method on the actor, all without doing any awaiting. The isolation and synchronization is handled automatically for us. This is incredibly useful and important to understand, especially at times when it can be very important to know what actor we are running on, such as the case when dealing with UI APIs.
		Task {
			try await Task.sleep(nanoseconds: NSEC_PER_SEC/2)
			if self.count < 0 {
				self.increment()
			}
		}
	}
}

// We can even give this feature a spin by firing up 1,000 tasks to hammer on the decrement endpoint, and then after waiting a bit of time we can confirm that the count was restored back to 0:
// This is very cool. There are a lot of opportunities for race conditions in this code, not only when we hammer on the decrement endpoint, but also once the small delay passes and we increment back up.
// But the compiler is keeping us in check that we are not accidentally accessing mutable data in a non-isolated way, and the actor synchronizes access to the data automatically, and we can write our code in a very natural way without worrying about locks.
Task {
	let counter = Counter()
	for _ in 0..<workcount {
		Task {
			await counter.decrement()
		}
	}
	Thread.sleep(forTimeInterval: 1)
	print(await counter.count)
}




Thread.sleep(forTimeInterval: 5)
