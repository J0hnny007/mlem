//
//  Comment Item Logic.swift
//  Mlem
//
//  Created by Eric Andrews on 2023-06-20.
//

import SwiftUI

extension CommentItem {
    func voteOnComment(inputOp: ScoringOperation) async {
        let operation = hierarchicalComment.commentView.myVote == inputOp ? ScoringOperation.resetVote : inputOp
        do {
            let updatedComment = try await commentRepository.voteOnComment(
                id: hierarchicalComment.commentView.id,
                vote: operation
            )
            commentTracker.comments.update(with: updatedComment)
        } catch {
            errorHandler.handle(
                .init(underlyingError: error)
            )
        }
    }
    
    func deleteComment() async {
        let comment = hierarchicalComment.commentView.comment
        do {
            let updatedComment = try await commentRepository.deleteComment(
                id: comment.id,
                // TODO: the UI for this only allows delete, but the operation can be undone it appears...
                shouldDelete: true
            )
            commentTracker.comments.update(with: updatedComment.commentView)
        } catch {
            errorHandler.handle(
                .init(underlyingError: error)
            )
        }
    }
    
    func upvote() async {
        // don't do anything if currently awaiting a vote response
        guard dirty else {
            // fake downvote
            switch displayedVote {
            case .upvote:
                dirtyVote = .resetVote
                dirtyScore = displayedScore - 1
            case .resetVote:
                dirtyVote = .upvote
                dirtyScore = displayedScore + 1
            case .downvote:
                dirtyVote = .upvote
                dirtyScore = displayedScore + 2
            }
            dirty = true

            // wait for vote
            await voteOnComment(inputOp: .upvote)

            // unfake downvote and restore state
            dirty = false
            return
        }
    }

    func downvote() async {
        // don't do anything if currently awaiting a vote response
        guard dirty else {
            // fake upvote
            switch displayedVote {
            case .upvote:
                dirtyVote = .downvote
                dirtyScore = displayedScore - 2
            case .resetVote:
                dirtyVote = .downvote
                dirtyScore = displayedScore - 1
            case .downvote:
                dirtyVote = .resetVote
                dirtyScore = displayedScore + 1
            }
            dirty = true

            // wait for vote
            await voteOnComment(inputOp: .downvote)

            // unfake upvote
            dirty = false
            return
        }
    }
    
    func replyToComment() {
        editorTracker.openEditor(with: ConcreteEditorModel(appState: appState,
                                                           comment: hierarchicalComment.commentView,
                                                           commentTracker: commentTracker,
                                                           operation: CommentOperation.replyToComment))
    }

    func editComment() {
        editorTracker.openEditor(with: ConcreteEditorModel(appState: appState,
                                                           comment: hierarchicalComment.commentView,
                                                           commentTracker: commentTracker,
                                                           operation: CommentOperation.editComment))
    }
    
    /**
     Asynchronous wrapper around replyToComment so that it can be used in swipey actions
     */
    func replyToCommentAsyncWrapper() async {
        replyToComment()
    }

    /**
     Sends a save request for the current post
     */
    func saveComment() async {
        guard !dirty else {
            return
        }
        
        defer { dirty = false }
        dirty = true
        dirtySaved.toggle()
        
        do {
            let response = try await commentRepository.saveComment(
                id: hierarchicalComment.id,
                shouldSave: dirtySaved
            )
            
            commentTracker.comments.update(with: response.commentView)
        } catch {
            errorHandler.handle(
                .init(underlyingError: error)
            )
        }

    }
    
    // MARK: helpers
    
    // swiftlint:disable function_body_length
    func genMenuFunctions() -> [MenuFunction] {
        var ret: [MenuFunction] = .init()
        
        // upvote
        let (upvoteText, upvoteImg) = hierarchicalComment.commentView.myVote == .upvote ?
        ("Undo upvote", "arrow.up.square.fill") :
        ("Upvote", "arrow.up.square")
        ret.append(MenuFunction(
            text: upvoteText,
            imageName: upvoteImg,
            destructiveActionPrompt: nil,
            enabled: true) {
            Task(priority: .userInitiated) {
                await upvote()
            }
        })
        
        // downvote
        let (downvoteText, downvoteImg) = hierarchicalComment.commentView.myVote == .downvote ?
        ("Undo downvote", "arrow.down.square.fill") :
        ("Downvote", "arrow.down.square")
        ret.append(MenuFunction(
            text: downvoteText,
            imageName: downvoteImg,
            destructiveActionPrompt: nil,
            enabled: true) {
            Task(priority: .userInitiated) {
                await downvote()
            }
        })
        
        // save
        let (saveText, saveImg) = hierarchicalComment.commentView.saved ? ("Unsave", "bookmark.slash") : ("Save", "bookmark")
        ret.append(MenuFunction(
            text: saveText,
            imageName: saveImg,
            destructiveActionPrompt: nil,
            enabled: true) {
            Task(priority: .userInitiated) {
                await saveComment()
            }
        })
        
        // reply
        ret.append(MenuFunction(
            text: "Reply",
            imageName: "arrowshape.turn.up.left",
            destructiveActionPrompt: nil,
            enabled: true) {
                replyToComment()
            })
        
        // edit
        if hierarchicalComment.commentView.creator.id == appState.currentActiveAccount.id {
            ret.append(MenuFunction(
                text: "Edit",
                imageName: "pencil",
                destructiveActionPrompt: nil,
                enabled: true) {
                    editComment()
                })
        }
        
        // delete
        if hierarchicalComment.commentView.creator.id == appState.currentActiveAccount.id {
            ret.append(MenuFunction(
                text: "Delete",
                imageName: "trash",
                destructiveActionPrompt: "Are you sure you want to delete this comment?  This cannot be undone.",
                enabled: !hierarchicalComment.commentView.comment.deleted) {
                Task(priority: .userInitiated) {
                    await deleteComment()
                }
            })
        }
        
        // share
        if let url = URL(string: hierarchicalComment.commentView.comment.apId) {
            ret.append(MenuFunction(
                text: "Share",
                imageName: "square.and.arrow.up",
                destructiveActionPrompt: nil,
                enabled: true) {
                showShareSheet(URLtoShare: url)
            })
        }
        
        // report
        ret.append(MenuFunction(
            text: "Report",
            imageName: AppConstants.reportSymbolName,
            destructiveActionPrompt: nil,
            enabled: true) {
                editorTracker.openEditor(with: ConcreteEditorModel(appState: appState,
                                                                   comment: hierarchicalComment.commentView,
                                                                   operation: CommentOperation.reportComment))
            })
        
        // block
        ret.append(MenuFunction(text: "Block User",
                                imageName: AppConstants.blockUserSymbolName,
                                destructiveActionPrompt: nil,
                                enabled: true) {
            Task(priority: .userInitiated) {
                await blockUser(userId: hierarchicalComment.commentView.creator.id)
            }
        })
                   
        return ret
    }
    
    func blockUser(userId: Int) async {
        do {
            let blocked = try await blockPerson(
                account: appState.currentActiveAccount,
                personId: userId,
                blocked: true
            )
            
            // TODO: remove from feed--requires generic feed tracker support for removing by filter condition
            if blocked {
                await notifier.add(.success("Blocked user"))
                commentTracker.filter { comment in
                    comment.commentView.creator.id != userId
                }
            }
        } catch {
            errorHandler.handle(
                .init(
                    message: "Unable to block user",
                    style: .toast,
                    underlyingError: error
                )
            )
        }
    }
    // swiftlint:enable function_body_length
}
