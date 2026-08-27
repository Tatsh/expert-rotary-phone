//
//  QuizCell.h
//  pop'n rhythmin
//
//  A quiz answer row: an answer-base image (default / cover / ok / ng) behind a
//  centered answer label, plus a small answer-number badge on the side.
//  Reconstructed from Ghidra project rb420, program PopnRhythmin
//  (initWithStyle:reuseIdentifier: @ 0xd9bac).
//

#import <UIKit/UIKit.h>

/**
 * @brief One answer-choice row of the quiz.
 */
@interface QuizCell : UITableViewCell

/**
 * @brief Bind the row to one answer choice.
 *
 * The base image, label tint and number badge all key off the relationship between the three ids.
 * @param text The answer text.
 * @param answerId This row's answer index.
 * @param rightId The correct answer's index.
 * @param selectId The answer the player chose; negative when unanswered.
 */
- (void)setData:(NSString *)text answerId:(int)answerId rightId:(int)rightId selectId:(int)selectId;

@end

// kate: hl Objective-C; replace-tabs on; indent-width 4; tab-width 4;
// vim: set ft=objc sw=4 ts=4 et :
// code: language=Objective-C insertSpaces=true tabSize=4
