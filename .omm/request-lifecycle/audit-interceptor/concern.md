The audit row is written after the handler's own transaction has committed, in a separate query; if that insert fails the client receives an error although the change was applied.
