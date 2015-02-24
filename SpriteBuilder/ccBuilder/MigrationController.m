#import "MigrationController.h"

#import "ResourcePathToPackageMigrator.h"
#import "MigrationViewController.h"
#import "NSError+SBErrors.h"
#import "Errors.h"
#import "MigrationLogger.h"


@implementation MigrationController


- (BOOL)migrateWithError:(NSError **)error
{
    if ([_migrators count] == 0)
    {
        [NSError setNewErrorWithErrorPointer:error code:SBProjectMigrationError message:@"No migrators set up"];
        return NO;
    }

    if (![self needsMigration])
    {
        return YES;
    }

    if (![self askDelegateHowToProceed])
    {
        [NSError setNewErrorWithErrorPointer:error code:SBCCBMigrationCancelledError message:@"Cancelled by delegate"];
        return NO;
    }

    if (![self doMigrateWithError:error])
    {
        return NO;
    }

    [self tidyUp];

    return YES;
}

- (void)tidyUp
{
    for (id <MigratorProtocol> migrator in _migrators)
    {
        if ([migrator respondsToSelector:@selector(tidyUp)])
        {
            [migrator tidyUp];
        }
    }
}

- (BOOL)doMigrateWithError:(NSError **)error
{
    NSMutableArray *stepsTpRollback = [NSMutableArray array];

    for (id <MigratorProtocol> migrator in _migrators)
    {
        if ([migrator respondsToSelector:@selector(setLogger:)])
        {
            [migrator setLogger:_logger];
        }

        [stepsTpRollback addObject:migrator];
        if (![migrator migrateWithError:error])
        {
            for (id <MigratorProtocol> migrationStepToRollback in stepsTpRollback)
            {
                [migrationStepToRollback rollback];
            }
            return NO;
        }
    }

    return YES;
}

- (BOOL)askDelegateHowToProceed
{
    if (!_delegate)
    {
        return YES;
    }
    
    return [_delegate migrateWithMigrationDetails:[self infoTextsAsHtmlOfAllMigrationSteps]];
}

- (NSString *)infoTextsAsHtmlOfAllMigrationSteps
{
    NSMutableString *result = [NSMutableString string];

    [result appendString:@"<small><ul>"];

    for (id <MigratorProtocol> migrationStep in _migrators)
    {
        if ([migrationStep isMigrationRequired])
        {
            [result appendString:@"<li>"];
            [result appendString:[migrationStep htmlInfoText]];
            [result appendString:@"</li>"];
        }
    }
    [result appendString:@"</ul></small>"];

    return result;
}

- (BOOL)needsMigration
{
    for (id <MigratorProtocol> migrationStep in _migrators)
    {
        if ([migrationStep isMigrationRequired])
        {
            return YES;
        }
    }
    return NO;
}

@end
