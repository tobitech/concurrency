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
//actor Counter {
//	var count = 0
//
//	func increment() {
//		self.count += 1
//	}
//
//	func decrement() {
//		self.count -= 1
		// This is compiling only because the Task is inheriting the current actor context.
		// And this compiles. But perhaps it’s a little surprising that it compiles.
		// After all, so far whenever we have tried accessing methods and properties on actors we have be forced to await it:
		// The only exception was when writing code directly in the actor:
		// Now technically the task code is inside the actor, but as we’ve noted before, the closure used in the task initializer is an @escaping and @Sendable closure, which means for all intents and purposes it really is its own execution context. How on earth is it possible that we are able to reach out from this escaped context and access the actor’s properties without having to await for synchronization?
		// This is possible specifically because this task inherits its actor’s context. It is allowed to interact with the actor as if it was code written directly in a method on the actor, all without doing any awaiting. The isolation and synchronization is handled automatically for us. This is incredibly useful and important to understand, especially at times when it can be very important to know what actor we are running on, such as the case when dealing with UI APIs.
//		Task {
//			try await Task.sleep(nanoseconds: NSEC_PER_SEC/2)
//			if self.count < 0 {
//				self.count += 1
//			}
//		}
//	}
//}

// We can even give this feature a spin by firing up 1,000 tasks to hammer on the decrement endpoint, and then after waiting a bit of time we can confirm that the count was restored back to 0:
// This is very cool. There are a lot of opportunities for race conditions in this code, not only when we hammer on the decrement endpoint, but also once the small delay passes and we increment back up.
// But the compiler is keeping us in check that we are not accidentally accessing mutable data in a non-isolated way, and the actor synchronizes access to the data automatically, and we can write our code in a very natural way without worrying about locks.
//Task {
//	let counter = Counter()
//	for _ in 0..<workcount {
//		Task {
//			await counter.decrement()
//		}
//	}
//	Thread.sleep(forTimeInterval: 1)
//	print(await counter.count)
//}


// There is another way to create tasks that fully detaches you from the current context. It doesn’t inherit the priority, task locals or actor:
// as soon as we use Task.detached, we start getting compiler errors because it no longer operates in the context of the Counter actor.
// The only way to fix this is to
//actor Counter {
//	var count = 0
//
//	func increment() {
//		self.count += 1
//	}
//
//	func decrement() {
//		self.count -= 1
//		Task.detached {
//			try await Task.sleep(nanoseconds: NSEC_PER_SEC/2)
//			// if self.count < 0 { // 🛑 Expression is 'async' but is not marked with 'await'
//			if await self.count < 0 {
//				// self.count += 1 // 🛑 Actor-isolated property 'count' can not be mutated from a Sendable closure
//				await self.increment()
//			}
//		}
//	}
//}

// Detached Task also do not inherit Priority.
//print(Task.currentPriority)
//Task(priority: .low) {
//	print(Task.currentPriority)
//	Task.detached {
//		print(Task.currentPriority) // 21
//	}
//}

// Output
//TaskPriority(rawValue: 33)
//TaskPriority(rawValue: 17)
//TaskPriority(rawValue: 21) // default priority

// Detached Task also do not inheric Task local values.
//print("before:", MyLocals.id)
//MyLocals.$id.withValue(42) {
//	print(("withValue:", MyLocals.id!))
//	Task.detached {
//		print("Task:", MyLocals.id) // nil
//	}
//}
//print("after:", MyLocals.id)

// Output
//before: nil
//("withValue:", 42)
//after: nil
//Task: nil

// It’s worth noting that even some of the tools for structured concurrency in Swift do not inherit everything from the current task.
// In particular, @Sendable closures, async let, and task groups do not inherit the current actor context.
// suppose that we did something silly like accessed an actor’s property inside a synchronous closure that is executed immediately:
//actor Counter {
//	var count = 0
//
//	//func increment() {
//	func increment() async {
//		self.count += 1
//
//		// This is completely fine to do.
//		// let count = { self.count }()
//		// However if we force the closure to be Sendable.
//		// We get an error that is because the compiler no longer thinks we're accessing self.count in an isolated manner because the sendable closure is no longer being operated in the context of the Counter actor
//		// let count = { @Sendable in self.count }() // 🛑 Actor-isolated property 'count' can not be referenced from a Sendable closure
//		// to fix this we have to mark it async and await it.
//		// Even though Task closure is marked as @Sendable, it inherits the actor context because of a special compiler attribute `@_inheritActorContext`
//		let count = await { @Sendable in await self.count }()
//	}
//
//	func decrement() {
//		self.count -= 1
//		Task.detached {
//			try await Task.sleep(nanoseconds: NSEC_PER_SEC/2)
//			if await self.count < 0 {
//				await self.increment()
//			}
//		}
//	}
//}

// async let also looses it actor context.
//actor Counter {
//	var count = 0
//
//	func increment() async {
//		self.count += 1
//
//		// let count = { self.count }()
//		// instead of just calling count synchronously, we bind using async let.
//		// we get some errors:
//		// 🛑 'async let' in a function that does not support concurrency
//		// 🛑 Actor-isolated property 'count' can not be referenced from a non-isolated context
//		// 🛑 Add 'async' to function 'increment()' to make it asynchronous
//		// Since async let’s whole purpose is to run code concurrently, this closure is being implicitly updated to be @Sendable.
//		// async let count = { self.count }()
//		// to fix this we await accessing the count so that it can be isolated
//		async let count = { await self.count }()
//	}
//
//	func decrement() {
//		self.count -= 1
//		Task.detached {
//			try await Task.sleep(nanoseconds: NSEC_PER_SEC/2)
//			if await self.count < 0 {
//				await self.increment()
//			}
//		}
//	}
//}

// Task groups also do not inherit their actor context.
// To see this, let’s implement a silly method on Counter that spins up 1,000 tasks, and randomly either increments or decrements the counter:
// Although task groups don't inherit the current actor context, they do inherit the locals.
actor Counter {
	var count = 0
	
	func increment() async {
		self.count += 1
		// let's spin off a task group, in it we spin off 1,000 child tasks
		await withTaskGroup(of: Void.self) { group in
			for _ in 1...1000 {
				// This doesn't compile because the closure passed to group.add { } does not inherit the current actor context
				// this means we need to use a child task's asychronous context to interact with the actor.
				await group.add {
					if Bool.random() {
						// self.count += 1 // 🛑 Actor-isolated property 'count' can not be mutated from a Sendable closure
						// we need to await an endpiont on the actor like `increment()` or `decrement()`
						await self.increment()
					} else {
						// self.count -= 1 // 🛑 Actor-isolated property 'count' can not be mutated from a Sendable closure
						await self.decrement()
					}
				}
			}
		}
		async let count = { await self.count }()
	}
	
	func decrement() {
		self.count -= 1
		Task.detached {
			try await Task.sleep(nanoseconds: NSEC_PER_SEC/2)
			if await self.count < 0 {
				await self.increment()
			}
		}
	}
}



Thread.sleep(forTimeInterval: 5)
